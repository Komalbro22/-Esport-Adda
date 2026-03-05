import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _upiCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _qrCodeUrl;
  final String _imgbbApiKey = 'b40febb06056bca6bfdae97dde6b481c'; // From user request

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await _supabase.from('payment_settings').select().maybeSingle();
      if (res != null) {
        _upiCtrl.text = res['upi_id'] ?? '';
        _qrCodeUrl = res['qr_code_url'];
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to load settings');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
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
        setState(() {
          _qrCodeUrl = jsonData['data']['url'];
        });
        StitchSnackbar.showSuccess(context, 'QR Code uploaded temporarily. Save changes to keep it.');
      } else {
        throw Exception('ImgBB API returned an error');
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to upload image. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final existing = await _supabase.from('payment_settings').select('id').maybeSingle();
      
      final data = {
        'upi_id': _upiCtrl.text.trim(),
        'qr_code_url': _qrCodeUrl ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        await _supabase.from('payment_settings').update(data).eq('id', existing['id']);
      } else {
        await _supabase.from('payment_settings').insert(data);
      }

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Payment settings saved successfully!');
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to save settings.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: StitchLoading());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: StitchCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure UPI and QR Code for Deposits',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StitchTheme.textMain),
              ),
              const SizedBox(height: 8),
              const Text(
                'These details will be shown to users when they add money to their wallet.',
                style: TextStyle(color: StitchTheme.textMuted, fontSize: 12),
              ),
              const Divider(height: 32, color: StitchTheme.surfaceHighlight),
              
              StitchInput(
                label: 'UPI ID',
                controller: _upiCtrl,
                hintText: 'e.g. yourname@upi',
              ),
              
              const SizedBox(height: 24),
              const Text('QR Code Image', style: TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
              const SizedBox(height: 12),
              
              Center(
                child: GestureDetector(
                  onTap: _isSaving ? null : _pickAndUploadImage,
                  child: Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      color: StitchTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: StitchTheme.primary.withOpacity(0.5)),
                      image: _qrCodeUrl != null && _qrCodeUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_qrCodeUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _qrCodeUrl == null || _qrCodeUrl!.isEmpty
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 48, color: StitchTheme.textMuted),
                              SizedBox(height: 8),
                              Text('Tap to upload QR', style: TextStyle(color: StitchTheme.textMuted)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: StitchButton(
                  text: _isSaving ? 'Saving...' : 'Save Settings',
                  onPressed: _isSaving ? null : _saveSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
