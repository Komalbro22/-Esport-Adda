import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GameManagementScreen extends StatefulWidget {
  const GameManagementScreen({Key? key}) : super(key: key);

  @override
  State<GameManagementScreen> createState() => _GameManagementScreenState();
}

class _GameManagementScreenState extends State<GameManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _games = [];

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    try {
      final data = await _supabase.from('games').select('*').order('created_at');
      if (mounted) {
        setState(() {
          _games = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? game]) {
    final nameCtrl = TextEditingController(text: game?['name']);
    final descCtrl = TextEditingController(text: game?['description']);
    final logoCtrl = TextEditingController(text: game?['logo_url']);
    bool isActive = game?['is_active'] ?? true;
    bool isUploading = false;

    Future<void> pickAndUpload(StateSetter setDialogState) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile == null) return;

      setDialogState(() => isUploading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        // Using the same key provided by user
        const apiKey = 'b40febb06056bca6bfdae97dde6b481c';
        
        final response = await http.post(
          Uri.parse('https://api.imgbb.com/1/upload'),
          body: {
            'key': apiKey,
            'image': base64Image,
          },
        );
        
        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          final url = jsonData['data']['url'];
          setDialogState(() {
             logoCtrl.text = url;
             isUploading = false;
          });
          StitchSnackbar.showSuccess(context, 'Image uploaded!');
        } else {
          throw Exception();
        }
      } catch (e) {
        setDialogState(() => isUploading = false);
        StitchSnackbar.showError(context, 'Image upload failed');
      }
    }

    StitchDialog.show(
      context: context,
      title: game == null ? 'Add Game' : 'Edit Game',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StitchInput(label: 'Game Name', controller: nameCtrl),
              const SizedBox(height: 12),
              StitchInput(label: 'Description', controller: descCtrl),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StitchInput(label: 'Logo URL', controller: logoCtrl)),
                  const SizedBox(width: 8),
                  if (isUploading)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_rounded, color: StitchTheme.primary),
                      tooltip: 'Upload Logo',
                      onPressed: () => pickAndUpload(setDialogState),
                    ),
                  IconButton(
                    icon: const Icon(Icons.collections, color: StitchTheme.primary),
                    tooltip: 'Pick from Assets',
                    onPressed: () async {
                      final selectedUrl = await context.push<String?>('/assets?selection=true');
                      if (selectedUrl != null) {
                        setDialogState(() => logoCtrl.text = selectedUrl);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Is Active', style: TextStyle(color: StitchTheme.textMain)),
                value: isActive,
                activeColor: StitchTheme.primary,
                onChanged: (v) => setDialogState(() => isActive = v),
              )
            ],
          );
        }
      ),
      primaryButtonText: 'Save',
      onPrimaryPressed: () async {
        if (nameCtrl.text.trim().isEmpty) {
          StitchSnackbar.showError(context, 'Name is required');
          return;
        }

        final payload = {
          'name': nameCtrl.text.trim(),
          'description': descCtrl.text.trim(),
          'logo_url': logoCtrl.text.trim().isEmpty ? null : logoCtrl.text.trim(),
          'is_active': isActive,
        };

        try {
          if (game == null) {
            await _supabase.from('games').insert(payload);
          } else {
            await _supabase.from('games').update(payload).eq('id', game['id']);
          }
          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, 'Saved successfully');
            _fetchGames();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to save');
        }
      }
    );
  }

  void _confirmDelete(Map<String, dynamic> game) {
    StitchDialog.show(
      context: context,
      title: 'Delete Game',
      content: Text('Are you sure you want to delete ${game['name']}? This may fail if tournaments are actively using it.', style: const TextStyle(color: StitchTheme.textMuted)),
      primaryButtonText: 'Delete',
      primaryButtonColor: StitchTheme.error,
      onPrimaryPressed: () async {
        try {
          await _supabase.from('games').delete().eq('id', game['id']);
          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, 'Game deleted');
            _fetchGames();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Game cannot be deleted. Try setting it to inactive.');
        }
      },
      secondaryButtonText: 'Cancel',
      onSecondaryPressed: () => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Games'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _games.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final game = _games[index];
                return StitchCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: StitchTheme.surfaceHighlight,
                      backgroundImage: game['logo_url'] != null ? NetworkImage(game['logo_url']) : null,
                      child: game['logo_url'] == null ? const Icon(Icons.sports_esports) : null,
                    ),
                    title: Text(game['name'], style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
                    subtitle: Text(game['is_active'] ? 'Active' : 'Inactive', style: TextStyle(color: game['is_active'] ? StitchTheme.success : StitchTheme.error)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: StitchTheme.primary),
                          onPressed: () => _showAddEditDialog(game),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: StitchTheme.error),
                          onPressed: () => _confirmDelete(game),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StitchTheme.primary,
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
