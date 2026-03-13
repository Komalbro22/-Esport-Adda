import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class LegalManagementScreen extends StatefulWidget {
  const LegalManagementScreen({Key? key}) : super(key: key);

  @override
  State<LegalManagementScreen> createState() => _LegalManagementScreenState();
}

class _LegalManagementScreenState extends State<LegalManagementScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _documents = [];
  String _selectedDocId = 'privacy_policy';
  final _contentController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isSaving = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal CMS'),
        bottom: isMobile ? TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Edit'), Tab(text: 'Preview')],
          indicatorColor: StitchTheme.primary,
        ) : null,
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _isSaving ? null : _saveDocument,
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            ),
        ],
      ),
      drawer: isMobile ? _buildSidebar() : null,
      body: _isLoading
          ? const StitchLoading()
          : isMobile ? _buildMobileBody() : _buildDesktopBody(),
    );
  }

  Widget _buildDesktopBody() {
    return Row(
      children: [
        _buildSidebar(),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildEditor()),
              const VerticalDivider(width: 1, color: StitchTheme.surfaceHighlight),
              Expanded(child: _buildPreview()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildEditor(),
        _buildPreview(),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: StitchTheme.surface,
        border: Border(right: BorderSide(color: StitchTheme.surfaceHighlight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('DOCUMENTS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, letterSpacing: 2)),
          ),
          Expanded(
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
                    if (MediaQuery.of(context).size.width < 900) {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
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
    );
  }

  Widget _buildPreview() {
    return Container(
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
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(color: StitchTheme.textMain),
                h1: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold),
                // Add more custom styles if needed
              ),
            ),
          ),
        ],
      ),
    );
  }
}
