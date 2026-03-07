import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      StitchSnackbar.showError(context, 'Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      // Verify Admin Role
      final userRec = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', res.user!.id)
          .single();

      if (userRec['role'] != 'admin' && userRec['role'] != 'superadmin') {
        await Supabase.instance.client.auth.signOut();
        if (mounted) StitchSnackbar.showError(context, 'Access Denied: Admins Only');
      } else {
        if (mounted) context.go('/dashboard');
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 16),
              const Text('Admin Portal', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
              const SizedBox(height: 32),
              StitchCard(
                child: Column(
                  children: [
                    StitchInput(
                      label: 'Admin Email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Password',
                      controller: _password,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    const SizedBox(height: 32),
                    StitchButton(
                      text: 'Login to Dashboard',
                      isLoading: _isLoading,
                      onPressed: _login,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
