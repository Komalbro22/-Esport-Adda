import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({Key? key}) : super(key: key);

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not found';

      // 1. Check if user already has a referral code (generated in OTP stage)
      final profile = await Supabase.instance.client
          .from('users')
          .select('referral_code')
          .eq('id', user.id)
          .maybeSingle();

      final String userCode = profile?['referral_code'] ?? 
          'ESD${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      // 2. Update public.users record
      await Supabase.instance.client.from('users').upsert({
        'id': user.id,
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'referral_code': userCode,
      });

      // 3. Sync OneSignal ID again to ensure it's captured now that records are established
      try {
        await OneSignalService().syncPlayerId();
      } catch (_) {}

      // 4. Apply referral if given (Edge Function)
      final refCode = _referralController.text.trim();
      if (refCode.isNotEmpty) {
        await Supabase.instance.client.functions.invoke(
          'apply_referral_bonus',
          body: {
            'referral_code': refCode,
            'new_user_id': user.id
          },
        );
      }

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Profile completed successfully!');
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to complete profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Complete Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: StitchTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us a bit more about yourself.',
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
                      hintText: 'Choose a unique username',
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
                      label: 'Referral Code (Optional)',
                      controller: _referralController,
                      prefixIcon: const Icon(Icons.card_giftcard_outlined),
                      hintText: 'Enter referral code',
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: StitchButton(
                        text: 'Get Started',
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
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
