import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:intl/intl.dart';

class AdminActivityLogScreen extends StatefulWidget {
  final String? filterAdminId;
  const AdminActivityLogScreen({Key? key, this.filterAdminId}) : super(key: key);

  @override
  State<AdminActivityLogScreen> createState() => _AdminActivityLogScreenState();
}

class _AdminActivityLogScreenState extends State<AdminActivityLogScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  String _selectedAction = 'all';

  final _actionFilters = {
    'all': 'All',
    'create_admin': 'Create Admin',
    'edit_admin_permissions': 'Edit Permissions',
    'block_admin': 'Block',
    'unblock_admin': 'Unblock',
    'delete_admin': 'Delete Admin',
    'approve_deposit': 'Deposit',
    'approve_withdraw': 'Withdraw',
    'cancel_tournament': 'Cancel Tournament',
    'distribute_prizes': 'Prize Distribution',
  };

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      // .eq() (filter) must be called BEFORE .order()/.limit() (transforms)
      final data = await (widget.filterAdminId != null
          ? _supabase
              .from('admin_activity_logs')
              .select()
              .eq('admin_id', widget.filterAdminId!)
              .order('created_at', ascending: false)
              .limit(200)
          : _supabase
              .from('admin_activity_logs')
              .select()
              .order('created_at', ascending: false)
              .limit(200));

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_selectedAction == 'all') return _logs;
    return _logs.where((l) => l['action'] == _selectedAction).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Action filter chips
          Container(
            color: StitchTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _actionFilters.entries.map((entry) {
                  final isSelected = _selectedAction == entry.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAction = entry.key),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? StitchTheme.primary : StitchTheme.surfaceHighlight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isSelected ? Colors.white : StitchTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const StitchLoading()
                : _filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.history_rounded, size: 48, color: StitchTheme.textMuted),
                            SizedBox(height: 12),
                            Text('No activity logs found', style: TextStyle(color: StitchTheme.textMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          return _buildLogTile(log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final action = log['action'] ?? 'unknown';
    final (icon, color) = _actionStyle(action);
    final details = log['details'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(log['created_at'] ?? '');

    return StitchCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _actionLabel(action),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('dd MMM, HH:mm').format(createdAt.toLocal()),
                        style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 12, color: StitchTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      log['admin_name'] ?? 'Unknown Admin',
                      style: const TextStyle(fontSize: 12, color: StitchTheme.primary),
                    ),
                  ],
                ),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: StitchTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: details.entries.map((e) {
                        return Text(
                          '${e.key}: ${e.value}',
                          style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(String action) {
    return {
      'create_admin': '👤 Created New Admin',
      'edit_admin_permissions': '✏️ Edited Admin Permissions',
      'block_admin': '🔒 Blocked Admin',
      'unblock_admin': '🔓 Unblocked Admin',
      'delete_admin': '🗑️ Removed Admin Role',
      'approve_deposit': '💰 Approved Deposit',
      'reject_deposit': '❌ Rejected Deposit',
      'approve_withdraw': '💸 Approved Withdrawal',
      'reject_withdraw': '❌ Rejected Withdrawal',
      'cancel_tournament': '🏆 Cancelled Tournament',
      'distribute_prizes': '🎁 Distributed Prizes',
      'block_user': '🚫 Blocked Player',
      'unblock_user': '✅ Unblocked Player',
    }[action] ?? action.replaceAll('_', ' ').toUpperCase();
  }

  (IconData, Color) _actionStyle(String action) {
    if (action.contains('create')) return (Icons.person_add_rounded, Colors.green);
    if (action.contains('delete') || action.contains('cancel')) return (Icons.delete_rounded, Colors.red);
    if (action.contains('block')) return (Icons.lock_rounded, Colors.orange);
    if (action.contains('unblock')) return (Icons.lock_open_rounded, Colors.green);
    if (action.contains('approve')) return (Icons.check_circle_rounded, Colors.green);
    if (action.contains('reject')) return (Icons.cancel_rounded, Colors.red);
    if (action.contains('permission')) return (Icons.admin_panel_settings_rounded, StitchTheme.primary);
    if (action.contains('prize')) return (Icons.emoji_events_rounded, Colors.amber);
    return (Icons.history_rounded, StitchTheme.textMuted);
  }
}
