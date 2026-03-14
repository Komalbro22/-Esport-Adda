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
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final username = _usernameController.text.trim();

      // Check if username is already taken
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (existingUser != null) {
        if (mounted) {
          StitchSnackbar.showError(context, 'Username already taken. Please choose another.');
        }
        setState(() => _isLoading = false);
        return;
      }

      await AuthService.signInWithOtp(email);
      
      if (mounted) {
        context.push('/otp', extra: {
          'email': email,
          'reason': OTPReason.signup,
          'signupData': {
            'name': _nameController.text.trim(),
            'username': username,
            'phone': _phoneController.text.trim(),
            'referred_by': _referralController.text.trim(),
          },
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
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                      label: 'Full Name',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      hintText: 'e.g. Komal Cheema',
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Username',
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.alternate_email),
                      hintText: 'Choose a unique username',
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (val.length < 3) return 'Too short';
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) return 'Letters, numbers, and underscores only';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Email Address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      hintText: 'Enter your email',
                      validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Phone Number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      hintText: 'e.g. +91 9876543210',
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Referral Code (Optional)',
                      controller: _referralController,
                      prefixIcon: const Icon(Icons.card_giftcard_outlined),
                      hintText: 'Enter referral code',
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
