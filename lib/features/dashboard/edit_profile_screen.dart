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
  final _usernameCtrl = TextEditingController(); // read-only usually, but let's show it
  
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
        setState(() {
          _nameCtrl.text = data['name'] ?? '';
          _usernameCtrl.text = data['username'] ?? '';
          _avatarUrl = data['avatar_url'];
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: StitchTheme.surfaceHighlight,
                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null 
                      ? const Icon(Icons.person, size: 60, color: StitchTheme.primary) 
                      : null,
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
                    // Typically username shouldn't change to prevent collision, but keeping it visible
                  ),
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
    );
  }
}
