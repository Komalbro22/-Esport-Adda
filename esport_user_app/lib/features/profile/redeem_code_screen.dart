import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';

class RedeemCodeScreen extends StatefulWidget {
  const RedeemCodeScreen({Key? key}) : super(key: key);

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final _codeController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isSubmitting = false;

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      StitchSnackbar.showError(context, 'Please enter a promo code');
      return;
    }

    final session = _supabase.auth.currentSession;
    if (session == null) {
      StitchSnackbar.showError(context, 'Session expired. Please log in again.');
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final response = await _supabase.functions.invoke(
        'redeem_promo_code',
        body: {'promo_code': code},
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': SupabaseConfig.anonKey,
          'X-Client-Info': 'supabase-flutter/2.0.0',
        },
      );

      final status = response.status;
      final data = response.data;

      if (status == 200 && data['success'] == true) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: StitchTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    'Success!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: StitchTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data['message'] ?? 'Promo code redeemed successfully.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                  const SizedBox(height: 32),
                  StitchButton(
                    text: 'Awesome',
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to profile
                    },
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          StitchSnackbar.showError(
            context,
            data['error'] ?? 'Failed to redeem code',
          );
        }
      }
    } catch (e) {
      debugPrint('Promo redemption error: $e');
      if (mounted) {
        StitchSnackbar.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redeem Promo Code')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.local_offer_outlined, size: 64, color: StitchTheme.primary),
            const SizedBox(height: 24),
            const Text(
              'Enter a Promo Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: StitchTheme.textMain),
            ),
            const SizedBox(height: 8),
            const Text(
              'Redeem special codes to get bonuses in your wallet.',
              style: TextStyle(color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                hintText: 'e.g. WELCOME100',
                labelText: 'PROMO CODE',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              textCapitalization: TextCapitalization.characters,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 32),
            StitchButton(
              text: 'Redeem Now',
              onPressed: _isSubmitting ? null : _redeemCode,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: StitchTheme.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
