import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'website_management_screen.dart';
import 'package:esport_core/services/imgbb_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _signupBonusController = TextEditingController();
  final _referralSenderController = TextEditingController();
  final _referralReceiverController = TextEditingController();
  final _leaderboardLimitController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _logoUrl;
  String? _adminLogoUrl;
  String? _settingsId;
  String _version = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchSettings();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = "${packageInfo.version}+${packageInfo.buildNumber}";
      });
    }
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
            _adminLogoUrl = data['admin_logo_url'];
            _signupBonusController.text = (data['signup_bonus'] ?? 0).toString();
            _referralSenderController.text = (data['referral_bonus_sender'] ?? 0).toString();
            _referralReceiverController.text = (data['referral_bonus_receiver'] ?? 0).toString();
            _leaderboardLimitController.text = (data['leaderboard_limit'] ?? 50).toString();
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

  Future<void> _pickAndUploadAdminLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isSaving = true);
    
    try {
      final url = await ImgBBService.uploadImage(file);
      if (url != null) {
        setState(() => _adminLogoUrl = url);
        StitchSnackbar.showSuccess(context, 'Admin Logo uploaded');
      } else {
        StitchSnackbar.showError(context, 'Failed to upload admin logo');
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
        'admin_logo_url': _adminLogoUrl,
        'signup_bonus': double.tryParse(_signupBonusController.text) ?? 10,
        'referral_bonus_sender': double.tryParse(_referralSenderController.text) ?? 10,
        'referral_bonus_receiver': double.tryParse(_referralReceiverController.text) ?? 10,
        'leaderboard_limit': int.tryParse(_leaderboardLimitController.text) ?? 50,
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
                  const Text('Website Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.web, color: StitchTheme.primary),
                    title: const Text('Control Website Links & Stats', style: TextStyle(color: StitchTheme.textMain)),
                    trailing: const Icon(Icons.chevron_right, color: StitchTheme.textMuted),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WebsiteManagementScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: StitchTheme.surfaceHighlight),
                  const SizedBox(height: 24),
                  const Text('App Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 24),
                  
                  // Logo Uploader
                  const Text('App Logo', style: TextStyle(fontWeight: FontWeight.w600, color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildLogoPreview(_logoUrl, 'User Logo'),
                        const SizedBox(width: 24),
                        StitchButton(
                          text: 'Upload User Logo',
                          isSecondary: true,
                          isLoading: _isSaving,
                          onPressed: _pickAndUploadLogo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Admin Logo', style: TextStyle(fontWeight: FontWeight.w600, color: StitchTheme.textMain)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildLogoPreview(_adminLogoUrl, 'Admin Logo'),
                        const SizedBox(width: 24),
                        StitchButton(
                          text: 'Upload Admin Logo',
                          isSecondary: true,
                          isLoading: _isSaving,
                          onPressed: _pickAndUploadAdminLogo,
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
            
            const SizedBox(height: 24),
            
            StitchCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bonuses & Referrals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 24),
                  StitchInput(
                    label: 'Signup Bonus (₹)',
                    controller: _signupBonusController,
                    keyboardType: TextInputType.number,
                    hintText: 'Given to every new user',
                  ),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'Referral Bonus - Sender (₹)',
                    controller: _referralSenderController,
                    keyboardType: TextInputType.number,
                    hintText: 'Given to the referrer',
                  ),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'Referral Bonus - Receiver (₹)',
                    controller: _referralReceiverController,
                    keyboardType: TextInputType.number,
                    hintText: 'Given to the person who joins',
                  ),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'Leaderboard Display Limit',
                    controller: _leaderboardLimitController,
                    keyboardType: TextInputType.number,
                    hintText: 'Number of players to show in leaderboard',
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
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Admin App Version $_version',
                style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  Widget _buildLogoPreview(String? url, String label) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: StitchTheme.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
        image: url != null ? DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover) : null,
      ),
      child: url == null ? const Icon(Icons.image, color: StitchTheme.textMuted, size: 30) : null,
    );
  }
}
