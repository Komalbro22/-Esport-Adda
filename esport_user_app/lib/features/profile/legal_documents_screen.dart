import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalDocumentsScreen extends StatefulWidget {
  final String docId;
  const LegalDocumentsScreen({Key? key, required this.docId}) : super(key: key);

  @override
  State<LegalDocumentsScreen> createState() => _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends State<LegalDocumentsScreen> {
  bool _isLoading = true;
  String _content = '';
  String _title = '';

  @override
  void initState() {
    super.initState();
    _fetchDocument();
  }

  Future<void> _fetchDocument() async {
    try {
      final data = await Supabase.instance.client
          .from('legal_documents')
          .select()
          .eq('id', widget.docId)
          .single();
      
      if (mounted) {
        setState(() {
          _content = data['content'] ?? 'No content available.';
          _title = data['title'] ?? 'Legal Document';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load document');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : _title),
      ),
      body: _isLoading
          ? const StitchLoading()
          : Markdown(
              data: _content,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(color: StitchTheme.textMain, fontSize: 14),
                h1: const TextStyle(color: StitchTheme.primary, fontSize: 24, fontWeight: FontWeight.bold),
                h2: const TextStyle(color: StitchTheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
                listBullet: const TextStyle(color: StitchTheme.primary),
              ),
            ),
    );
  }
}
