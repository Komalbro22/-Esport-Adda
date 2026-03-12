import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController(); 
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _discordCtrl = TextEditingController();
  
  bool _showBio = true;
  bool _showPhone = false;
  bool _showSocials = true;
  bool _hideAvatar = false;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;
  
  // The provided ImgBB API key
  final String _imgbbApiKey = 'b40febb06056bca6bfdae97dde6b481c';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase.from('users').select().eq('id', user.id).single();
      
      if (mounted) {
        final social = data['social_links'] as Map<String, dynamic>? ?? {};
        setState(() {
          _nameCtrl.text = data['name'] ?? '';
          _usernameCtrl.text = data['username'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _bioCtrl.text = data['bio'] ?? '';
          _instagramCtrl.text = social['instagram'] ?? '';
          _discordCtrl.text = social['discord'] ?? '';
          _avatarUrl = data['avatar_url'];
          
          _showBio = data['show_bio'] ?? true;
          _showPhone = data['show_phone'] ?? false;
          _showSocials = data['show_socials'] ?? true;
          _hideAvatar = data['hide_avatar'] ?? false;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load profile');
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    
    if (image == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {
          'key': _imgbbApiKey,
          'image': base64Image,
        },
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final url = jsonResponse['data']['url'];
        
        setState(() {
          _avatarUrl = url;
        });
        StitchSnackbar.showSuccess(context, 'Image uploaded successfully!');
      } else {
        throw Exception('ImgBB Upload Failed');
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to upload image. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      StitchSnackbar.showError(context, 'Name cannot be empty');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('users').update({
        'name': name,
        'phone': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'social_links': {
          'instagram': _instagramCtrl.text.trim(),
          'discord': _discordCtrl.text.trim(),
        },
        'show_bio': _showBio,
        'show_phone': _showPhone,
        'show_socials': _showSocials,
        'hide_avatar': _hideAvatar,
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
      }).eq('id', user.id);
      
      if (mounted) {
         StitchSnackbar.showSuccess(context, 'Profile updated successfully!');
         context.pop(true); // Return true to signal refresh needed
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to save profile');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: StitchLoading());
    }
    
    final ScrollController scrollController = ScrollController();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Scrollbar(
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  StitchAvatar(
                    radius: 60,
                    name: _nameCtrl.text.trim(),
                    avatarUrl: _avatarUrl,
                  ),
                  Positioned(
                    bottom: 0,
                    right: -10,
                    child: GestureDetector(
                      onTap: _isSaving ? null : _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: StitchTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Tap the camera icon to upload a profile logo', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
              
              const SizedBox(height: 32),
              
              StitchCard(
                child: Column(
                  children: [
                    StitchInput(
                      label: 'Name',
                      controller: _nameCtrl,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Username',
                      controller: _usernameCtrl,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Phone Number',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'Bio',
                      controller: _bioCtrl,
                      maxLines: 3,
                      hintText: 'Tell us about yourself...',
                    ),
                    const SizedBox(height: 24),
                    const Text('SOCIAL LINKS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    StitchInput(
                      label: 'Instagram Username',
                      controller: _instagramCtrl,
                      hintText: '@username',
                    ),
                    const SizedBox(height: 12),
                    StitchInput(
                      label: 'Discord ID',
                      controller: _discordCtrl,
                      hintText: 'username#0000',
                    ),
                    const SizedBox(height: 32),
                    const Text('PRIVACY SETTINGS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    _buildPrivacyToggle('Show Bio on Public Profile', _showBio, (v) => setState(() => _showBio = v)),
                    _buildPrivacyToggle('Show Phone Number', _showPhone, (v) => setState(() => _showPhone = v)),
                    _buildPrivacyToggle('Show Social Links', _showSocials, (v) => setState(() => _showSocials = v)),
                    _buildPrivacyToggle('Hide Profile Picture (Show Initials)', _hideAvatar, (v) => setState(() => _hideAvatar = v)),
                    const SizedBox(height: 32),
                    if (_isSaving)
                      const Center(child: StitchLoading())
                    else
                      StitchButton(
                        text: 'Save Changes',
                        onPressed: _saveProfile,
                      ),
                  ],
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyToggle(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeColor: StitchTheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}
