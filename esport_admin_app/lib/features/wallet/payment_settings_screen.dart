import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _upiIdCtrl = TextEditingController();
  final _upiNameCtrl = TextEditingController();
  final _minDepositCtrl = TextEditingController(text: '10');
  bool _isLoading = true;
  bool _isSaving = false;
  String? _qrCodeUrl;
  String? _existingId;
  final String _imgbbApiKey = 'b40febb06056bca6bfdae97dde6b481c';

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await _supabase.from('payment_settings').select().maybeSingle();
      if (res != null) {
        _existingId = res['id']?.toString();
        _upiIdCtrl.text = res['upi_id'] ?? '';
        _upiNameCtrl.text = res['upi_name'] ?? '';
        _minDepositCtrl.text = (res['minimum_deposit'] ?? 10).toString();
        _qrCodeUrl = res['upi_qr_url'] ?? res['qr_code_url'];
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to load settings');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadQR() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (pickedFile == null) return;

    setState(() => _isSaving = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final uri = Uri.parse('https://api.imgbb.com/1/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['key'] = _imgbbApiKey
        ..fields['image'] = base64Image;

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData);

      if (jsonData['success'] == true) {
        setState(() => _qrCodeUrl = jsonData['data']['url']);
        StitchSnackbar.showSuccess(context, 'QR uploaded — click Save to apply');
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Upload failed. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_upiIdCtrl.text.trim().isEmpty) {
      StitchSnackbar.showError(context, 'UPI ID is required');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Use a fixed UUID string to ensure we only ever have ONE row
      const String settingsId = '00000000-0000-0000-0000-000000000001';
      
      final data = {
        'id': settingsId,
        'upi_id': _upiIdCtrl.text.trim(),
        'upi_name': _upiNameCtrl.text.trim(),
        'upi_qr_url': _qrCodeUrl ?? '',
        'qr_code_url': _qrCodeUrl ?? '', 
        'minimum_deposit': double.tryParse(_minDepositCtrl.text.trim()) ?? 10,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Use upsert to overwrite the master row
      await _supabase.from('payment_settings').upsert(data);

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Payment settings saved successfully!');
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to save settings: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StitchTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StitchTheme.primary.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: StitchTheme.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'These settings control how users pay. A UPI deep link is generated automatically from the UPI ID.',
                      style: TextStyle(color: StitchTheme.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // UPI Settings Card
            StitchCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UPI DETAILS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'UPI ID',
                    controller: _upiIdCtrl,
                    hintText: 'e.g. esportadda@upi',
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  ),
                  const SizedBox(height: 12),
                  StitchInput(
                    label: 'Display Name (shown to users)',
                    controller: _upiNameCtrl,
                    hintText: 'e.g. Esport Adda',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  const SizedBox(height: 12),
                  StitchInput(
                    label: 'Minimum Deposit (₹)',
                    controller: _minDepositCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // QR Code Card
            StitchCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('QR CODE', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  const Text('Users can scan this to pay directly', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: _isSaving ? null : _pickAndUploadQR,
                      child: Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          color: StitchTheme.surfaceHighlight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _qrCodeUrl != null
                                ? StitchTheme.primary.withOpacity(0.3)
                                : StitchTheme.surfaceHighlight,
                            width: 2,
                          ),
                          image: _qrCodeUrl != null && _qrCodeUrl!.isNotEmpty
                              ? DecorationImage(image: CachedNetworkImageProvider(_qrCodeUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _qrCodeUrl == null || _qrCodeUrl!.isEmpty
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_scanner_rounded, size: 48, color: StitchTheme.textMuted),
                                  SizedBox(height: 8),
                                  Text('Tap to upload QR', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                                ],
                              )
                            : Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.primary.withOpacity(0.9),
                                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
                                  ),
                                  child: const Text('TAP TO CHANGE', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Preview UPI link
                  if (_upiIdCtrl.text.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StitchTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PREVIEW LINK', style: TextStyle(color: StitchTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          SelectableText(
                            'upi://pay?pa=${_upiIdCtrl.text.trim()}&pn=${Uri.encodeComponent(_upiNameCtrl.text.trim())}&am=100&cu=INR',
                            style: const TextStyle(color: StitchTheme.primary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: StitchButton(
                text: 'Save Payment Settings',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
