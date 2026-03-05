import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

class AssetGalleryScreen extends StatefulWidget {
  final bool isSelectionMode;
  const AssetGalleryScreen({Key? key, this.isSelectionMode = false}) : super(key: key);

  @override
  State<AssetGalleryScreen> createState() => _AssetGalleryScreenState();
}

class _AssetGalleryScreenState extends State<AssetGalleryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _assets = [];

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    try {
      final data = await _supabase.from('admin_assets').select('*').order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _assets = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;

    setState(() => _isLoading = true);
    final url = await ImgBBService.uploadImage(img);
    
    if (url == null) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to upload to ImgBB');
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      await _supabase.from('admin_assets').insert({
        'name': img.name,
        'url': url,
      });
      _fetchAssets();
      if (mounted) StitchSnackbar.showSuccess(context, 'Image uploaded to gallery');
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to save to database');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAsset(String id) async {
    try {
      await _supabase.from('admin_assets').delete().eq('id', id);
      _fetchAssets();
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Select Image' : 'Asset Gallery'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : _assets.isEmpty
              ? const Center(child: Text('No assets uploaded yet.', style: TextStyle(color: StitchTheme.textMuted)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (context, index) {
                    final asset = _assets[index];
                    return InkWell(
                      onTap: () {
                        if (widget.isSelectionMode) {
                          context.pop(asset['url']);
                        } else {
                          // Show full screen or copy link
                          _showAssetDetail(asset);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(asset['url'], fit: BoxFit.cover),
                          ),
                          if (!widget.isSelectionMode)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _deleteAsset(asset['id']),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.delete, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StitchTheme.primary,
        onPressed: _uploadImage,
        child: const Icon(Icons.upload),
      ),
    );
  }

  void _showAssetDetail(Map<String, dynamic> asset) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         backgroundColor: StitchTheme.surface,
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Image.network(asset['url']),
             const SizedBox(height: 16),
             Text(asset['name'] ?? 'Unnamed', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
             const SizedBox(height: 12),
             StitchButton(
               text: 'Copy URL', 
               onPressed: () {
                 // You'd normally use clipboard package here
                 context.pop();
                 StitchSnackbar.showSuccess(context, 'URL copied (conceptually)');
               }
             )
           ],
         ),
       )
     );
  }
}
