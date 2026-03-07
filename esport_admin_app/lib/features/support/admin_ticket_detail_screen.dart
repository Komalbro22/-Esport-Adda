import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const AdminTicketDetailScreen({Key? key, required this.ticketId}) : super(key: key);

  @override
  State<AdminTicketDetailScreen> createState() => _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState extends State<AdminTicketDetailScreen> {
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
    _channel = _supabase.channel('admin_support_messages:${widget.ticketId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'support_messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'ticket_id', value: widget.ticketId),
        callback: (payload) {
          final newMsg = payload.newRecord;
          if (mounted) {
            setState(() {
              _messages.add(newMsg);
            });
            _scrollToBottom();
          }
        },
      )
      .subscribe();
  }

  Future<void> _fetchData() async {
    try {
      final ticket = await _supabase.from('support_tickets').select('*, users(*)').eq('id', widget.ticketId).single();
      final msgs = await _supabase.from('support_messages').select().eq('ticket_id', widget.ticketId).order('created_at');
      
      if (mounted) {
        setState(() {
          _ticket = ticket;
          _messages = List<Map<String, dynamic>>.from(msgs);
          _isLoading = false;
        });
        _scrollToBottom();
      }
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
      final role = AdminPermissionService.isSuperAdmin ? 'super_admin' : 'admin';
      
      await _supabase.from('support_messages').insert({
        'ticket_id': widget.ticketId,
        'sender_id': userId,
        'message': text,
        'image_url': imageUrl,
        'sender_role': role,
      });
      _msgCtrl.clear();
      
      // Update status to in_progress if it was open
      if (_ticket?['status'] == 'open') {
        _updateStatus('in_progress');
      }
    } catch (e) {
      StitchSnackbar.showError(context, 'Failed to send');
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
      
      final response = await http.post(Uri.parse('https://api.imgbb.com/1/upload'), body: {'key': apiKey, 'image': base64Image});
      if (response.statusCode == 200) {
        final url = jsonDecode(response.body)['data']['url'];
        await _sendMessage(imageUrl: url);
      }
    } catch (e) {
      StitchSnackbar.showError(context, 'Upload failed');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await _supabase.from('support_tickets').update({'status': status}).eq('id', widget.ticketId);
      setState(() {
        _ticket!['status'] = status;
      });
      StitchSnackbar.showSuccess(context, 'Status updated to $status');
    } catch (e) {
      debugPrint('Update Status Error: $e');
      if (mounted) StitchSnackbar.showError(context, 'Failed to update status: ${e.toString()}');
    }
  }

  Future<void> _updatePriority(String priority) async {
    try {
      await _supabase.from('support_tickets').update({'priority': priority}).eq('id', widget.ticketId);
      setState(() {
        _ticket!['priority'] = priority;
      });
      StitchSnackbar.showSuccess(context, 'Priority updated to $priority');
    } catch (e) {
      StitchSnackbar.showError(context, 'Failed to update priority');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: StitchLoading()));
    if (_ticket == null) return const Scaffold(body: Center(child: Text('Ticket not found')));

    final user = _ticket!['users'];
    final status = _ticket!['status'];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?['name'] ?? 'Support Chat', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('ID: ${widget.ticketId.substring(0, 8)} • ${_ticket!['subject']}'.toUpperCase(), style: const TextStyle(fontSize: 9, color: StitchTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded, color: StitchTheme.primary),
            onPressed: _showManagementOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUserInfoBar(user),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildUserInfoBar(Map<String, dynamic>? user) {
    final status = _ticket?['status'] ?? 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: StitchTheme.surfaceHighlight.withOpacity(0.5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: StitchTheme.surfaceHighlight,
            backgroundImage: user?['avatar_url'] != null ? NetworkImage(user!['avatar_url']) : null,
            child: user?['avatar_url'] == null ? const Icon(Icons.person, size: 12) : null,
          ),
          const SizedBox(width: 8),
          Text(user?['username'] ?? 'User', style: const TextStyle(fontSize: 12, color: StitchTheme.textMain)),
          const Spacer(),
          _buildBadge(status.toUpperCase(), _getStatusColor(status)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isAdmin = msg['sender_role'] == 'admin' || msg['sender_role'] == 'super_admin';
    final time = DateFormat('HH:mm').format(DateTime.parse(msg['created_at']).toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isAdmin ? StitchTheme.primary : StitchTheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isAdmin ? 12 : 0),
                bottomRight: Radius.circular(isAdmin ? 0 : 12),
              ),
              border: isAdmin ? null : Border.all(color: Colors.white.withOpacity(0.05)),
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
                        child: Image.network(msg['image_url'], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                if (msg['message'] != null && msg['message'].toString().isNotEmpty)
                  Text(msg['message'], style: TextStyle(color: isAdmin ? Colors.white : StitchTheme.textMain, fontSize: 13.5)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 9, color: StitchTheme.textMuted)),
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
          IconButton(icon: _isUploading ? const StitchLoading() : const Icon(Icons.add_photo_alternate_rounded, color: StitchTheme.primary), onPressed: _isUploading ? null : _pickAndSendImage),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: StitchTheme.textMain, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type reply...',
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
            child: IconButton(icon: _isSending ? const StitchLoading() : const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: _isSending ? null : () => _sendMessage()),
          ),
        ],
      ),
    );
  }

  void _showManagementOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: StitchTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
            const SizedBox(height: 24),
            const Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: StitchTheme.textMuted, letterSpacing: 1)),
            const SizedBox(height: 12),
            Row(
              children: [
                _optionChip('in_progress', 'IN PROGRESS', StitchTheme.warning),
                const SizedBox(width: 8),
                _optionChip('resolved', 'RESOLVED', StitchTheme.success),
                const SizedBox(width: 8),
                _optionChip('closed', 'CLOSED', StitchTheme.textMuted),
              ],
            ),
            const SizedBox(height: 24),
            const Text('PRIORITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: StitchTheme.textMuted, letterSpacing: 1)),
            const SizedBox(height: 12),
            Row(
              children: [
                _priorityChip('low', 'LOW', Colors.blue),
                const SizedBox(width: 8),
                _priorityChip('normal', 'NORMAL', Colors.orange),
                const SizedBox(width: 8),
                _priorityChip('high', 'HIGH', Colors.red),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _optionChip(String value, String label, Color color) {
    bool isSelected = _ticket!['status'] == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          _updateStatus(value);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.05))),
          child: Center(child: Text(label, style: TextStyle(color: isSelected ? color : StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _priorityChip(String value, String label, Color color) {
    bool isSelected = _ticket!['priority'] == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          _updatePriority(value);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.05))),
          child: Center(child: Text(label, style: TextStyle(color: isSelected ? color : StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open': return StitchTheme.secondary;
      case 'in_progress': return StitchTheme.warning;
      case 'resolved': return StitchTheme.success;
      case 'closed': return StitchTheme.textMuted;
      default: return StitchTheme.primary;
    }
  }

  void _viewImage(String url) {
    showDialog(context: context, builder: (context) => InteractiveViewer(child: Center(child: Image.network(url))));
  }
}
