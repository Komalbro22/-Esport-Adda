import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      StitchSnackbar.showError(context, 'Please enter your email');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.resetPassword(_emailController.text.trim());
      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Password reset link sent to your email');
        context.pop();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString());
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
              'Enter your registered email address and we will send you a link to reset your password.',
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
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: StitchButton(
                      text: 'Send Reset Link',
                      isLoading: _isLoading,
                      onPressed: _resetPassword,
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
