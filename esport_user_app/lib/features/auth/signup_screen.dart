import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      // Create user
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'name': _nameController.text.trim(),
          'role': 'player',
        },
      );
      
      if (response.user != null) {
        // Wait briefly for the auth trigger to create the public.users record
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Generate a random referral code
        final userCode = 'ESD${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

        await Supabase.instance.client.from('users').update({
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'referral_code': userCode,
        }).eq('id', response.user!.id);

        // Apply referral if given (Edge Function)
        final refCode = _referralController.text.trim();
        if (refCode.isNotEmpty) {
           await Supabase.instance.client.functions.invoke(
             'apply_referral_bonus',
             body: {
               'referral_code': refCode,
               'new_user_id': response.user!.id
             },
             headers: {
               'Authorization': 'Bearer ${response.session?.accessToken ?? ''}',
               'apikey': SupabaseConfig.anonKey,
             },
           );
        }

        if (mounted) {
          StitchSnackbar.showSuccess(context, 'Account created successfully!');
          context.go('/dashboard');
        }
      }
    } on AuthException catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.message);
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to create account: $e');
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
                      label: 'Full Name',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Username',
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.alternate_email),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Phone Number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Password',
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (val) => val == null || val.length < 6 ? 'Min 6 chars' : null,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Referral Code (Optional)',
                      controller: _referralController,
                      prefixIcon: const Icon(Icons.card_giftcard_outlined),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: StitchButton(
                        text: 'Sign Up',
                        isLoading: _isLoading,
                        onPressed: _signup,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32), // bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
