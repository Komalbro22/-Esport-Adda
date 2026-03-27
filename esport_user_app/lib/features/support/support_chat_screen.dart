import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class SupportChatScreen extends StatefulWidget {
  final String ticketId;
  const SupportChatScreen({Key? key, required this.ticketId}) : super(key: key);

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    _channel = _supabase.channel('support_messages:${widget.ticketId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'support_messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'ticket_id', value: widget.ticketId),
        callback: (payload) {
          final newMsg = payload.newRecord;
          setState(() {
            _messages.add(newMsg);
          });
          _scrollToBottom();
        },
      )
      .subscribe();
  }

  Future<void> _fetchData() async {
    try {
      final ticket = await _supabase.from('support_tickets').select().eq('id', widget.ticketId).single();
      final msgs = await _supabase.from('support_messages').select().eq('ticket_id', widget.ticketId).order('created_at');
      
      setState(() {
        _ticket = ticket;
        _messages = List<Map<String, dynamic>>.from(msgs);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    setState(() => _isSending = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('support_messages').insert({
        'ticket_id': widget.ticketId,
        'sender_id': userId,
        'message': text,
        'image_url': imageUrl,
        'sender_role': 'player',
      });
      _msgCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      StitchSnackbar.showError(context, 'Failed to send message');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      const apiKey = 'b40febb06056bca6bfdae97dde6b481c';
      
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {'key': apiKey, 'image': base64Image},
      );
      
      if (response.statusCode == 200) {
        final url = jsonDecode(response.body)['data']['url'];
        await _sendMessage(imageUrl: url);
      }
    } catch (e) {
      if (!mounted) return;
      StitchSnackbar.showError(context, 'Image upload failed');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _reopenTicket() async {
    try {
      await _supabase.from('support_tickets').update({'status': 'open'}).eq('id', widget.ticketId);
      _fetchData();
      if (!mounted) return;
      StitchSnackbar.showSuccess(context, 'Ticket re-opened');
    } catch (e) {
      if (!mounted) return;
      StitchSnackbar.showError(context, 'Failed to re-open');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: StitchLoading()));
    if (_ticket == null) return const Scaffold(body: Center(child: Text('Ticket not found')));

    final isResolved = _ticket!['status'] == 'resolved';
    final isClosed = _ticket!['status'] == 'closed';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_ticket!['subject'] ?? 'Support Chat', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('ID: ${widget.ticketId.substring(0, 8)} • ${_ticket!['status']}'.toUpperCase(), style: TextStyle(fontSize: 10, color: StitchTheme.primary, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
        actions: [
          if (isResolved)
            TextButton(onPressed: _reopenTicket, child: const Text('REOPEN', style: TextStyle(color: StitchTheme.primary, fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
            ),
          ),
          if (!isClosed) _buildInputArea()
          else _buildClosedInfo(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isMe = msg['sender_role'] == 'player';
    final time = DateFormat('HH:mm').format(DateTime.parse(msg['created_at']).toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? StitchTheme.primary : StitchTheme.surfaceHighlight,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg['image_url'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _viewImage(msg['image_url']),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(imageUrl: msg['image_url'], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                if (msg['message'] != null && msg['message'].toString().isNotEmpty)
                  Text(msg['message'], style: TextStyle(color: isMe ? Colors.white : StitchTheme.textMain, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(color: StitchTheme.surface, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        children: [
          IconButton(
            icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_photo_alternate_rounded, color: StitchTheme.primary),
            onPressed: _isUploading ? null : _pickAndSendImage,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: StitchTheme.textMain, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: const TextStyle(color: StitchTheme.textMuted),
                filled: true,
                fillColor: StitchTheme.surfaceHighlight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: StitchTheme.primary,
            child: IconButton(
              icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _isSending ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      color: Colors.black12,
      child: const Text('This ticket is closed. You can no longer send messages.', textAlign: TextAlign.center, style: TextStyle(color: StitchTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          InteractiveViewer(child: Center(child: CachedNetworkImage(imageUrl: url))),
          Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
        ],
      ),
    );
  }
}
