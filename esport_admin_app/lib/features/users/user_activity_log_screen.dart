import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:intl/intl.dart';

class UserActivityLogScreen extends StatefulWidget {
  const UserActivityLogScreen({Key? key}) : super(key: key);

  @override
  State<UserActivityLogScreen> createState() => _UserActivityLogScreenState();
}

class _UserActivityLogScreenState extends State<UserActivityLogScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('user_activity_logs')
          .select('*, users(username, email)')
          .order('created_at', ascending: false)
          .limit(100);
      
      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load user logs');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Activity Logs'),
        actions: [
          IconButton(onPressed: _fetchLogs, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const StitchLoading()
          : _logs.isEmpty
              ? const Center(child: Text('No activity logs found', style: TextStyle(color: StitchTheme.textMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) => const Divider(color: StitchTheme.surfaceHighlight),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final user = log['users'] as Map<String, dynamic>?;
                    final date = DateTime.parse(log['created_at']).toLocal();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getActivityColor(log['activity_type']),
                        child: Icon(_getActivityIcon(log['activity_type']), color: Colors.white, size: 20),
                      ),
                      title: Text(log['description'] ?? 'No description', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('By: ${user?['username'] ?? 'Unknown'} (${user?['email'] ?? 'N/A'})', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(DateFormat('MMM dd, yyyy HH:mm').format(date), style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline, size: 20, color: StitchTheme.textMuted),
                        onPressed: () => _showLogDetails(log),
                      ),
                    );
                  },
                ),
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailItem('Type', log['activity_type']),
              _detailItem('Created At', log['created_at']),
              _detailItem('User ID', log['user_id']),
              const SizedBox(height: 16),
              const Text('Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(log['metadata'].toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
          Text(value ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'tournament_join': return Colors.blue;
      case 'referral_given': return Colors.green;
      case 'referral_received': return Colors.teal;
      case 'password_change': return Colors.orange;
      case 'login': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'tournament_join': return Icons.sports_esports;
      case 'referral_given': return Icons.group_add;
      case 'referral_received': return Icons.card_giftcard;
      case 'password_change': return Icons.password;
      case 'login': return Icons.login;
      default: return Icons.history;
    }
  }
}
