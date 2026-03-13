import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'otp_verification_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await AuthService.signInWithOtp(email);
      
      if (mounted) {
        context.push('/otp', extra: {
          'email': email,
          'reason': OTPReason.signup,
          'signupData': null, // We'll collect profile data AFTER verification as per user request
        });
      }
    } on AuthException catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.message);
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to send verification code');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: StitchTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join the ultimate esports platform.',
                style: TextStyle(color: StitchTheme.textMuted),
              ),
              const SizedBox(height: 32),
              
              StitchCard(
                child: Column(
                  children: [
                    StitchInput(
                      label: 'Email Address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      hintText: 'Enter your email',
                      validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: StitchButton(
                        text: 'Send Verification Code',
                        isLoading: _isLoading,
                        onPressed: _sendOTP,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text('By continuing, you agree to our ', style: TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
                    GestureDetector(
                      onTap: () => context.push('/legal/terms_and_conditions'),
                      child: const Text('Terms', style: TextStyle(color: StitchTheme.primary, fontSize: 13, decoration: TextDecoration.underline)),
                    ),
                    const Text(' & ', style: TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
                    GestureDetector(
                      onTap: () => context.push('/legal/privacy_policy'),
                      child: const Text('Privacy Policy', style: TextStyle(color: StitchTheme.primary, fontSize: 13, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
