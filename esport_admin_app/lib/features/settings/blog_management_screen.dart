import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class BlogManagementScreen extends StatefulWidget {
  const BlogManagementScreen({Key? key}) : super(key: key);

  @override
  State<BlogManagementScreen> createState() => _BlogManagementScreenState();
}

class _BlogManagementScreenState extends State<BlogManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('blog_posts').select().order('published_at', ascending: false);
      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load posts');
      }
    }
  }

  void _showEditDialog({Map<String, dynamic>? post}) async {
    final isEdit = post != null;
    final slugCtrl = TextEditingController(text: post?['slug'] ?? '');
    final titleCtrl = TextEditingController(text: post?['title'] ?? '');
    final excerptCtrl = TextEditingController(text: post?['excerpt'] ?? '');
    final contentCtrl = TextEditingController(text: post?['content'] ?? '');
    final categoryCtrl = TextEditingController(text: post?['category'] ?? 'news');
    final imageCtrl = TextEditingController(text: post?['image_url'] ?? '');
    bool isPublished = post?['is_published'] ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: StitchTheme.surface,
          title: Text(isEdit ? 'Edit Post' : 'New Post', style: const TextStyle(color: StitchTheme.textMain)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: slugCtrl, decoration: const InputDecoration(labelText: 'Slug (URL-friendly)'), style: const TextStyle(color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title'), style: const TextStyle(color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                  TextField(controller: excerptCtrl, decoration: const InputDecoration(labelText: 'Excerpt'), maxLines: 2, style: const TextStyle(color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                  TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category (e.g. tips, updates, news)'), style: const TextStyle(color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                  TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Image URL (optional)'), style: const TextStyle(color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                  TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Content (Markdown)'), maxLines: 12, style: const TextStyle(color: StitchTheme.textMain)),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Published', style: TextStyle(color: StitchTheme.textMain)),
                    value: isPublished,
                    onChanged: (v) => setDialogState(() => isPublished = v ?? true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (slugCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                  StitchSnackbar.showError(context, 'Slug, title and content required');
                  return;
                }
                try {
                  final payload = {
                    'slug': slugCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-_]'), '-'),
                    'title': titleCtrl.text.trim(),
                    'excerpt': excerptCtrl.text.trim(),
                    'content': contentCtrl.text.trim(),
                    'category': categoryCtrl.text.trim().isEmpty ? 'news' : categoryCtrl.text.trim(),
                    'image_url': imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
                    'is_published': isPublished,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  };
                  if (isEdit) {
                    await _supabase.from('blog_posts').update(payload).eq('id', post!['id']);
                  } else {
                    await _supabase.from('blog_posts').insert(payload);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    _fetchPosts();
                    StitchSnackbar.showSuccess(context, isEdit ? 'Post updated' : 'Post created');
                  }
                } catch (e) {
                  if (mounted) StitchSnackbar.showError(context, 'Failed: $e');
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog Management', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showEditDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 64, color: StitchTheme.textMuted),
                      const SizedBox(height: 16),
                      const Text('No blog posts yet', style: TextStyle(color: StitchTheme.textMuted)),
                      const SizedBox(height: 8),
                      StitchButton(text: 'Create Post', onPressed: () => _showEditDialog()),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _posts.length,
                  itemBuilder: (_, i) {
                    final p = _posts[i];
                    return StitchCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      onTap: () => _showEditDialog(post: p),
                      child: Row(
                        children: [
                          if (p['image_url'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(p['image_url'], width: 80, height: 60, fit: BoxFit.cover),
                            )
                          else
                            Container(width: 80, height: 60, decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.image, color: StitchTheme.textMuted)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                                Text(p['slug'] ?? '', style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: (p['is_published'] == true ? StitchTheme.success : StitchTheme.warning).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                      child: Text(p['is_published'] == true ? 'Published' : 'Draft', style: TextStyle(fontSize: 10, color: p['is_published'] == true ? StitchTheme.success : StitchTheme.warning)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(p['category'] ?? 'news', style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDialog(post: p)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
