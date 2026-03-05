import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:esport_core/services/imgbb_service.dart';
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _logoUrl;
  String? _settingsId;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final data = await _supabase.from('app_settings').select().limit(1).maybeSingle();
      if (mounted) {
        setState(() {
          if (data != null) {
            _settingsId = data['id'];
            _nameController.text = data['app_name'] ?? 'Esport Adda';
            _logoUrl = data['logo_url'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load app settings');
      }
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();

    setState(() => _isSaving = true);
    
    try {
      final url = await ImgBBService.uploadImage(file);
      if (url != null) {
        setState(() => _logoUrl = url);
        StitchSnackbar.showSuccess(context, 'Logo uploaded to ImgBB');
      } else {
        StitchSnackbar.showError(context, 'Failed to upload logo');
      }
    } catch (e) {
      StitchSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_nameController.text.trim().isEmpty) {
      StitchSnackbar.showError(context, 'App Name cannot be empty');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updates = {
        'app_name': _nameController.text.trim(),
        'logo_url': _logoUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (_settingsId != null) {
        await _supabase.from('app_settings').update(updates).eq('id', _settingsId!);
      } else {
        await _supabase.from('app_settings').insert(updates);
      }

      if (mounted) StitchSnackbar.showSuccess(context, 'Settings Saved Successfully');
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to save settings');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
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
                  const Text('App Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 24),
                  
                  // Logo Uploader
                  const Text('App Logo', style: TextStyle(fontWeight: FontWeight.w600, color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: StitchTheme.surfaceHighlight,
                          borderRadius: BorderRadius.circular(12),
                          image: _logoUrl != null ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover) : null,
                        ),
                        child: _logoUrl == null ? const Icon(Icons.image, color: StitchTheme.textMuted, size: 30) : null,
                      ),
                      const SizedBox(width: 24),
                      StitchButton(
                        text: 'Upload New Logo',
                        isSecondary: true,
                        isLoading: _isSaving,
                        onPressed: _pickAndUploadLogo,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(color: StitchTheme.surfaceHighlight),
                  const SizedBox(height: 24),
                  
                  // App Name
                  StitchInput(
                    label: 'App Name',
                    controller: _nameController,
                    hintText: 'e.g., Esport Adda',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: StitchButton(
                text: 'Save Settings',
                onPressed: _saveSettings,
                isLoading: _isSaving,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
