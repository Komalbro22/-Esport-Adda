import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (pass.isEmpty || confirm.isEmpty) {
      StitchSnackbar.showError(context, 'Please fill all fields');
      return;
    }

    if (pass != confirm) {
      StitchSnackbar.showError(context, 'Passwords do not match');
      return;
    }

    if (pass.length < 6) {
      StitchSnackbar.showError(context, 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.updatePassword(pass);
      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Password updated successfully. Please login with your new password.');
        // Log out to ensure they login with new credentials if needed, 
        // though Supabase often keeps the session. 
        // For clarity, let's redirect to login.
        context.go('/login');
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
        title: const Text('New Password'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set New Password',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: StitchTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enter your new password below.',
              style: TextStyle(color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 32),
            StitchCard(
              child: Column(
                children: [
                  StitchInput(
                    label: 'New Password',
                    controller: _passwordController,
                    isPassword: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'Confirm New Password',
                    controller: _confirmPasswordController,
                    isPassword: true,
                    prefixIcon: const Icon(Icons.lock_reset),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: StitchButton(
                      text: 'Update Password',
                      isLoading: _isLoading,
                      onPressed: _updatePassword,
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
