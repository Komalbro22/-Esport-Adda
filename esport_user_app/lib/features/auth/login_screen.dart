import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (response.user != null) {
        // Check if user is blocked or has wrong role before proceeding
        final userData = await Supabase.instance.client
          .from('users')
          .select('is_blocked, role')
          .eq('id', response.user!.id)
          .single();
          
        if (userData['is_blocked'] == true) {
          await Supabase.instance.client.auth.signOut();
          if(mounted) StitchSnackbar.showError(context, 'Account is blocked. Contact support.');
          return;
        }

        if (mounted) context.go('/dashboard');
      }
    } on AuthException catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.message);
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'An unexpected error occurred');
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
                'Enter your details to login.',
                style: TextStyle(color: StitchTheme.textMuted),
              ),
              const SizedBox(height: 48),
              
              StitchCard(
                child: Column(
                  children: [
                    StitchInput(
                      label: 'Email',
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Password',
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text('Forgot Password?', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: StitchButton(
                        text: 'Login',
                        isLoading: _isLoading,
                        onPressed: _login,
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
