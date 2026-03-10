import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      StitchSnackbar.showError(context, 'Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithOtp(email);
      if (mounted) {
        context.push('/otp', extra: {
          'email': email,
          'reason': OTPReason.login,
          'signupData': null,
        });
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to send OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 24),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: StitchTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your email to receive an OTP.',
                style: TextStyle(color: StitchTheme.textMuted),
              ),
              const SizedBox(height: 48),
              
              StitchCard(
                child: Column(
                  children: [
                    StitchInput(
                      label: 'Email Address',
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      hintText: 'Enter your registered email',
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: StitchButton(
                        text: 'Send OTP',
                        isLoading: _isLoading,
                        onPressed: _sendOTP,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.push('/signup'),
                child: const Text('Don\'t have an account? Sign Up', style: TextStyle(color: StitchTheme.primary)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
