import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendRecoveryOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      StitchSnackbar.showError(context, 'Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Supabase signInWithOtp works for password recovery if type is set in verifyOTP
      // or we can use resetPasswordForEmail which sends an OTP if configured
      await AuthService.signInWithOtp(email);
      
      if (mounted) {
        context.push('/otp', extra: {
          'email': email,
          'reason': OTPReason.reset,
          'signupData': null,
        });
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to send recovery code');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: StitchTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your registered email address and we will send you a 6-digit code to reset your password.',
              style: TextStyle(color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 32),
            StitchCard(
              child: Column(
                children: [
                  StitchInput(
                    label: 'Email',
                    controller: _emailController,
                    prefixIcon: const Icon(Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    hintText: 'Enter your email',
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: StitchButton(
                      text: 'Send Recovery Code',
                      isLoading: _isLoading,
                      onPressed: _sendRecoveryOTP,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
