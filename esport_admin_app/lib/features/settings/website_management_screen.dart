import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class WebsiteManagementScreen extends StatefulWidget {
  const WebsiteManagementScreen({Key? key}) : super(key: key);

  @override
  State<WebsiteManagementScreen> createState() => _WebsiteManagementScreenState();
}

class _WebsiteManagementScreenState extends State<WebsiteManagementScreen> {
  final _supabase = Supabase.instance.client;
  
  final _userApkController = TextEditingController();
  final _adminApkController = TextEditingController();
  final _userVersionController = TextEditingController();
  final _adminVersionController = TextEditingController();
  
  final _activePlayersController = TextEditingController();
  final _liveMatchesController = TextEditingController();
  final _totalTournamentsController = TextEditingController();
  final _prizeDistributedController = TextEditingController();

  final _supportEmailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _instagramController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final data = await _supabase.from('website_settings').select();
      
      if (mounted) {
        setState(() {
          for (var item in data) {
            final key = item['key'];
            final value = item['value'] as Map<String, dynamic>;
            
            if (key == 'apk_links') {
              _userApkController.text = value['user_app'] ?? '';
              _adminApkController.text = value['admin_app'] ?? '';
              _userVersionController.text = value['user_version'] ?? '';
              _adminVersionController.text = value['admin_version'] ?? '';
            } else if (key == 'app_stats') {
              _activePlayersController.text = value['active_players'] ?? '';
              _liveMatchesController.text = value['live_matches'] ?? '';
              _totalTournamentsController.text = value['total_tournaments'] ?? '';
              _prizeDistributedController.text = value['prize_distributed'] ?? '';
            } else if (key == 'contact_info') {
              _supportEmailController.text = value['email'] ?? '';
              _whatsappController.text = value['whatsapp'] ?? '';
              _instagramController.text = value['instagram'] ?? '';
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load website settings');
      }
    }
  }

  Future<void> _uploadApk(bool isUserApp) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(result.files.single.path!);
      final fileName = '${isUserApp ? 'user_app' : 'admin_app'}_${DateTime.now().millisecondsSinceEpoch}.apk';
      
      // 1. Upload to Supabase Storage
      await _supabase.storage.from('apks').upload(
        fileName,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      // 2. Get Public URL
      final publicUrl = _supabase.storage.from('apks').getPublicUrl(fileName);

      setState(() {
        if (isUserApp) {
          _userApkController.text = publicUrl;
        } else {
          _adminApkController.text = publicUrl;
        }
      });

      if (mounted) StitchSnackbar.showSuccess(context, 'APK Uploaded & Link Updated');
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to upload APK: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final apkLinks = {
        'user_app': _userApkController.text.trim(),
        'admin_app': _adminApkController.text.trim(),
        'user_version': _userVersionController.text.trim(),
        'admin_version': _adminVersionController.text.trim(),
      };

      final appStats = {
        'active_players': _activePlayersController.text.trim(),
        'live_matches': _liveMatchesController.text.trim(),
        'total_tournaments': _totalTournamentsController.text.trim(),
        'prize_distributed': _prizeDistributedController.text.trim(),
      };

      final contactInfo = {
        'email': _supportEmailController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'instagram': _instagramController.text.trim(),
      };

      await _supabase.from('website_settings').upsert({
        'key': 'apk_links',
        'value': apkLinks,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _supabase.auth.currentUser?.id,
      }, onConflict: 'key');

      await _supabase.from('website_settings').upsert({
        'key': 'app_stats',
        'value': appStats,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _supabase.auth.currentUser?.id,
      }, onConflict: 'key');

      await _supabase.from('website_settings').upsert({
        'key': 'contact_info',
        'value': contactInfo,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _supabase.auth.currentUser?.id,
      }, onConflict: 'key');

      if (mounted) StitchSnackbar.showSuccess(context, 'Website Settings Updated');
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
        title: const Text('Website Management', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSection(
              title: 'APK Downloads',
              children: [
                _buildApkInput(
                  label: 'User App APK Link', 
                  controller: _userApkController,
                  isUserApp: true,
                ),
                const SizedBox(height: 16),
                StitchInput(label: 'User App Version', controller: _userVersionController, hintText: 'e.g. 1.0.5'),
                const SizedBox(height: 24),
                _buildApkInput(
                  label: 'Admin App APK Link', 
                  controller: _adminApkController,
                  isUserApp: false,
                ),
                const SizedBox(height: 16),
                StitchInput(label: 'Admin App Version', controller: _adminVersionController, hintText: 'e.g. 1.0.2'),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Live Statistics',
              children: [
                Row(
                  children: [
                    Expanded(child: StitchInput(label: 'Active Players', controller: _activePlayersController, hintText: '50K+')),
                    const SizedBox(width: 16),
                    Expanded(child: StitchInput(label: 'Live Matches', controller: _liveMatchesController, hintText: '100+')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: StitchInput(label: 'Total Tournaments', controller: _totalTournamentsController, hintText: '500+')),
                    const SizedBox(width: 16),
                    Expanded(child: StitchInput(label: 'Prize Distributed', controller: _prizeDistributedController, hintText: '₹10L+')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Contact & Support',
              children: [
                StitchInput(label: 'Support Email', controller: _supportEmailController),
                const SizedBox(height: 16),
                StitchInput(label: 'WhatsApp Number', controller: _whatsappController),
                const SizedBox(height: 16),
                StitchInput(label: 'Instagram URL', controller: _instagramController),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: StitchButton(
                text: 'Update Website',
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

  Widget _buildApkInput({required String label, required TextEditingController controller, required bool isUserApp}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: StitchInput(label: label, controller: controller)),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _isUploading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    onPressed: () => _uploadApk(isUserApp),
                    icon: const Icon(Icons.upload_file, color: StitchTheme.primary),
                    tooltip: 'Upload APK',
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return StitchCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
