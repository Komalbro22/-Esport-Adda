import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

enum OTPReason { login, signup, reset }

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final OTPReason reason;
  final Map<String, dynamic>? signupData;

  const OTPVerificationScreen({
    Key? key,
    required this.email,
    required this.reason,
    this.signupData,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendCooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _resendOTP() async {
    if (_resendCooldown > 0) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithOtp(widget.email);
      _startCooldown();
      if (mounted) StitchSnackbar.showSuccess(context, 'OTP resent to your email');
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to resend OTP');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verify() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      StitchSnackbar.showError(context, 'Please enter the full 6-digit code');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final type = widget.reason == OTPReason.reset ? OtpType.recovery : OtpType.email;
      
      await AuthService.verifyOTP(
        email: widget.email,
        token: otp,
        type: type,
      );

      if (!mounted) return;

      if (widget.reason == OTPReason.signup) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          // Check if user already exists in public.users
          final existing = await Supabase.instance.client
              .from('users')
              .select('id, referral_code, username')
              .eq('id', user.id)
              .maybeSingle();

          // Generate a random referral code immediately so it's never NULL
          final String userCode = 'ESD${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
          
          final Map<String, dynamic> updates = {
            'id': user.id,
            'email': user.email,
            'referral_code': existing?['referral_code'] ?? userCode,
          };

          // If we have signupData (new flow), apply it
          if (widget.signupData != null) {
            updates['name'] = widget.signupData!['name'];
            updates['username'] = widget.signupData!['username'];
            updates['phone'] = widget.signupData!['phone'];
            
            // Check for referral by
            if (widget.signupData!['referred_by'] != null && widget.signupData!['referred_by'].toString().isNotEmpty) {
              updates['referred_by'] = widget.signupData!['referred_by'];
            }
          }

          await Supabase.instance.client.from('users').upsert(updates, onConflict: 'id');

          // Sync OneSignal Player ID immediately after verification
          try {
            await OneSignalService().syncPlayerId();
          } catch (e) {
            debugPrint('Failed to sync OneSignal on signup: $e');
          }

          // Wallet creation is now primarily handled by the DB trigger to ensure 
          // signup bonuses are awarded atomically. We still do a safety upsert.
          await Supabase.instance.client.from('user_wallets').upsert({
            'user_id': user.id,
          }, onConflict: 'user_id');

          // If we applied a referral, trigger the bonus
          if (widget.signupData != null && widget.signupData!['referred_by'] != null && widget.signupData!['referred_by'].toString().isNotEmpty) {
            try {
              await Supabase.instance.client.functions.invoke(
                'apply_referral_bonus',
                body: {
                  'referral_code': widget.signupData!['referred_by'],
                  'new_user_id': user.id
                },
                headers: {
                  'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
                  'apikey': SupabaseConfig.anonKey,
                },
              );
            } catch (e) {
              debugPrint('Referral bonus application failed: $e');
            }
          }

          if (mounted) context.go('/dashboard');
        }
      } else if (widget.reason == OTPReason.reset) {
        // Reset: Navigate to update password screen
        context.push('/reset-password');
      } else {
        // Login: Proceed to dashboard
        try {
          await OneSignalService().syncPlayerId();
          
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final profile = await Supabase.instance.client
                .from('users')
                .select('username')
                .eq('id', user.id)
                .maybeSingle();
            
            if (profile == null || profile['username'] == null) {
              if (mounted) context.go('/complete-profile');
              return;
            }
          }
        } catch (_) {}
        if (mounted) context.go('/dashboard');
      }
    } on AuthException catch (e) {
      if (mounted) {
        // More specific error message if possible
        String msg = 'Invalid or expired OTP';
        if (e.message.contains('expired')) msg = 'OTP has expired. Please resend.';
        StitchSnackbar.showError(context, msg);
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // DELETED _completeSignup as it is now handled by ProfileCompletionScreen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Verification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.mark_email_read_outlined, size: 80, color: StitchTheme.primary),
            const SizedBox(height: 32),
            const Text(
              'Verify Your Email',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: StitchTheme.textMain),
            ),
            const SizedBox(height: 12),
            Text(
              'We have sent a 6-digit code to\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 48),
            
            // OTP Input Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: 48,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextFormField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: StitchTheme.primary, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _focusNodes[index + 1].requestFocus();
                      }
                      if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                      if (index == 5 && value.isNotEmpty) {
                        _verify();
                      }
                    },
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: StitchButton(
                text: 'Verify OTP',
                isLoading: _isLoading,
                onPressed: _verify,
              ),
            ),
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Didn\'t receive code? ', style: TextStyle(color: StitchTheme.textMuted)),
                TextButton(
                  onPressed: _resendCooldown == 0 ? _resendOTP : null,
                  child: Text(
                    _resendCooldown == 0 ? 'Resend' : 'Resend in ${_resendCooldown}s',
                    style: TextStyle(
                      color: _resendCooldown == 0 ? StitchTheme.primary : StitchTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
