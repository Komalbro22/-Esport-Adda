import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';

class PaymentSettingsScreen extends StatefulWidget {
  final bool isNested;
  const PaymentSettingsScreen({Key? key, this.isNested = false}) : super(key: key);

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _supabase = Supabase.instance.client;
  
  String _activeMethod = 'manual_upi';
  bool _isTestMode = true;
  
  final _razorpayKeyIdController = TextEditingController();
  final _razorpaySecretKeyController = TextEditingController();
  final _razorpayWebhookSecretController = TextEditingController();
  
  final _minDepositController = TextEditingController();
  final _commissionController = TextEditingController();
  
  final _upiIdController = TextEditingController();
  final _upiNameController = TextEditingController();
  final _upiQrUrlController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _settingsId;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final data = await _supabase.from('payment_settings').select().limit(1).maybeSingle();
      if (mounted) {
        setState(() {
          if (data != null) {
            _settingsId = data['id'];
            _activeMethod = data['active_method'] ?? 'manual_upi';
            _isTestMode = data['is_test_mode'] ?? true;
            _razorpayKeyIdController.text = data['razorpay_key_id'] ?? '';
            _razorpaySecretKeyController.text = data['razorpay_secret_key'] ?? '';
            _razorpayWebhookSecretController.text = data['razorpay_webhook_secret'] ?? '';
            _minDepositController.text = (data['min_deposit'] ?? 10).toString();
            _commissionController.text = (data['commission_percentage'] ?? 0).toString();
            _upiIdController.text = data['upi_id'] ?? '';
            _upiNameController.text = data['upi_name'] ?? '';
            _upiQrUrlController.text = data['upi_qr_url'] ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load payment settings');
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final updates = {
        'active_method': _activeMethod,
        'razorpay_key_id': _razorpayKeyIdController.text.trim(),
        'razorpay_secret_key': _razorpaySecretKeyController.text.trim(),
        'razorpay_webhook_secret': _razorpayWebhookSecretController.text.trim(),
        'is_test_mode': _isTestMode,
        'min_deposit': double.tryParse(_minDepositController.text) ?? 10,
        'commission_percentage': double.tryParse(_commissionController.text) ?? 0,
        'upi_id': _upiIdController.text.trim(),
        'upi_name': _upiNameController.text.trim(),
        'upi_qr_url': _upiQrUrlController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (_settingsId != null) {
        final res = await _supabase.from('payment_settings').update(updates).eq('id', _settingsId!).select().single();
        _settingsId = res['id'];
      } else {
        final res = await _supabase.from('payment_settings').insert(updates).select().single();
        _settingsId = res['id'];
      }

      if (mounted) StitchSnackbar.showSuccess(context, 'Payment Settings Saved');
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to save: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());

    return Scaffold(
      backgroundColor: widget.isNested ? Colors.transparent : StitchTheme.background,
      appBar: widget.isNested ? null : AppBar(
        title: const Text('Payment Settings', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StitchCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Manual UPI', style: TextStyle(color: StitchTheme.textMain)),
                          value: 'manual_upi',
                          groupValue: _activeMethod,
                          activeColor: StitchTheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setState(() => _activeMethod = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Razorpay', style: TextStyle(color: StitchTheme.textMain)),
                          value: 'razorpay',
                          groupValue: _activeMethod,
                          activeColor: StitchTheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setState(() => _activeMethod = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            StitchCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('General Configurations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 24),
                  StitchInput(
                    label: 'Minimum Deposit Amount (₹)',
                    controller: _minDepositController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'Tournament Commission (%)',
                    controller: _commissionController,
                    keyboardType: TextInputType.number,
                    hintText: 'e.g., 10 for 10%',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_activeMethod == 'razorpay') ...[
              StitchCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Razorpay Keys', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                        Row(
                          children: [
                            const Text('Test Mode', style: TextStyle(color: StitchTheme.textMuted)),
                            Switch(
                              value: _isTestMode,
                              activeColor: StitchTheme.primary,
                              onChanged: (val) => setState(() => _isTestMode = val),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Key ID',
                      controller: _razorpayKeyIdController,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Secret Key (Hidden from Users)',
                      controller: _razorpaySecretKeyController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Webhook Secret',
                      controller: _razorpayWebhookSecretController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: StitchTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: StitchTheme.warning, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text('Only admins can view or change the secret key. It will never be exposed to the public API.', style: TextStyle(color: StitchTheme.warning, fontSize: 12))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              StitchCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Manual UPI Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                    const SizedBox(height: 24),
                    StitchInput(
                      label: 'UPI ID',
                      controller: _upiIdController,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Receiver Name',
                      controller: _upiNameController,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'QR Code URL (Optional)',
                      controller: _upiQrUrlController,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: StitchButton(
                text: 'Save Payment Settings',
                onPressed: _saveSettings,
                isLoading: _isSaving,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
