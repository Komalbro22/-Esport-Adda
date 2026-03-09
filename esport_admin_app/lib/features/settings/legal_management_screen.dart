import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class LegalManagementScreen extends StatefulWidget {
  const LegalManagementScreen({Key? key}) : super(key: key);

  @override
  State<LegalManagementScreen> createState() => _LegalManagementScreenState();
}

class _LegalManagementScreenState extends State<LegalManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _documents = [];
  String _selectedDocId = 'privacy_policy';
  final _contentController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('legal_documents').select().order('id');
      if (mounted) {
        setState(() {
          _documents = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
          _loadSelectedDoc();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load documents');
      }
    }
  }

  void _loadSelectedDoc() {
    final doc = _documents.firstWhere((d) => d['id'] == _selectedDocId, orElse: () => {});
    if (doc.isNotEmpty) {
      _contentController.text = doc['content'] ?? '';
      _titleController.text = doc['title'] ?? '';
    }
  }

  Future<void> _saveDocument() async {
    setState(() => _isSaving = true);
    try {
      await _supabase.from('legal_documents').update({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _selectedDocId);

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Document updated successfully');
        _fetchDocuments();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to save document');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal CMS'),
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _isSaving ? null : _saveDocument,
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            ),
        ],
      ),
      body: _isLoading
          ? const StitchLoading()
          : Row(
              children: [
                // Sidebar
                Container(
                  width: 250,
                  decoration: const BoxDecoration(
                    color: StitchTheme.surface,
                    border: Border(right: BorderSide(color: StitchTheme.surfaceHighlight)),
                  ),
                  child: ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      final isSelected = _selectedDocId == doc['id'];
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: StitchTheme.primary.withOpacity(0.1),
                        title: Text(doc['title'], style: TextStyle(color: isSelected ? StitchTheme.primary : StitchTheme.textMain)),
                        onTap: () {
                          setState(() {
                            _selectedDocId = doc['id'];
                            _loadSelectedDoc();
                          });
                        },
                      );
                    },
                  ),
                ),
                // Editor & Preview
                Expanded(
                  child: Row(
                    children: [
                      // Editor
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StitchInput(
                                label: 'Document Title',
                                controller: _titleController,
                              ),
                              const SizedBox(height: 24),
                              const Text('Content (Markdown)', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: TextField(
                                  controller: _contentController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(fontFamily: 'monospace', color: StitchTheme.textMain),
                                  decoration: InputDecoration(
                                    fillColor: StitchTheme.surface,
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onChanged: (v) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Preview
                      const VerticalDivider(width: 1, color: StitchTheme.surfaceHighlight),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          color: StitchTheme.background,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PREVIEW', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, letterSpacing: 2)),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Markdown(
                                  data: _contentController.text,
                                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
