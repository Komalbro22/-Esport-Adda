import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({Key? key}) : super(key: key);

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _admins = [];

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    try {
      final data = await _supabase
          .from('users')
          .select('*, admin_permissions(*)')
          .inFilter('role', ['admin', 'super_admin'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _admins = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlock(Map<String, dynamic> admin) async {
    final isBlocked = admin['is_blocked'] ?? false;
    final newState = !isBlocked;
    try {
      await _supabase
          .from('users')
          .update({'is_blocked': newState})
          .eq('id', admin['id']);

      await AdminLogService.log(
        action: newState ? 'block_admin' : 'unblock_admin',
        targetType: 'user',
        targetId: admin['id'],
        details: {'admin_email': admin['email']},
      );

      StitchSnackbar.showSuccess(context, newState ? 'Admin blocked' : 'Admin unblocked');
      _fetchAdmins();
    } catch (e) {
      StitchSnackbar.showError(context, 'Failed to update status');
    }
  }

  Future<void> _deleteAdmin(Map<String, dynamic> admin) async {
    if (admin['role'] == 'super_admin') {
      StitchSnackbar.showError(context, 'Super admin cannot be deleted');
      return;
    }

    StitchDialog.show(
      context: context,
      title: 'Delete Admin',
      content: Text('Delete admin @${admin['username']}? This cannot be undone.'),
      primaryButtonText: 'Delete',
      onPrimaryPressed: () async {
        try {
          await _supabase.from('users').update({'role': 'player'}).eq('id', admin['id']);

          await AdminLogService.log(
            action: 'delete_admin',
            targetType: 'user',
            targetId: admin['id'],
            details: {'admin_email': admin['email']},
          );

          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, 'Admin removed');
            _fetchAdmins();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to delete admin');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Management'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/admin_logs'),
            icon: const Icon(Icons.history_rounded, size: 18, color: StitchTheme.primary),
            label: const Text('Activity Logs', style: TextStyle(color: StitchTheme.primary, fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/create_admin');
          _fetchAdmins();
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Create Admin'),
        backgroundColor: StitchTheme.primary,
      ),
      body: _isLoading
          ? const StitchLoading()
          : _admins.isEmpty
              ? const Center(child: Text('No admins found', style: TextStyle(color: StitchTheme.textMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _admins.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final admin = _admins[index];
                    return _buildAdminCard(admin);
                  },
                ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final isSuperAdmin = admin['role'] == 'super_admin';
    final isBlocked = admin['is_blocked'] ?? false;
    final perms = admin['admin_permissions'];

    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: StitchTheme.surfaceHighlight,
                backgroundImage: admin['avatar_url'] != null ? NetworkImage(admin['avatar_url']) : null,
                child: admin['avatar_url'] == null
                    ? Icon(isSuperAdmin ? Icons.shield_rounded : Icons.admin_panel_settings_rounded,
                        color: isSuperAdmin ? Colors.amber : StitchTheme.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(admin['name'] ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 8),
                        _roleChip(admin['role']),
                      ],
                    ),
                    Text(admin['email'] ?? '', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              StitchBadge(
                text: isBlocked ? 'BLOCKED' : 'ACTIVE',
                color: isBlocked ? Colors.red : Colors.green,
              ),
            ],
          ),

          if (!isSuperAdmin && perms != null) ...[
            const SizedBox(height: 12),
            const Text('PERMISSIONS', style: TextStyle(fontSize: 10, color: StitchTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _permChip('Games', perms['can_manage_games'] == true),
                _permChip('Tournaments', perms['can_manage_tournaments'] == true),
                _permChip('Results', perms['can_manage_results'] == true),
                _permChip('Deposits', perms['can_manage_deposits'] == true),
                _permChip('Withdrawals', perms['can_manage_withdrawals'] == true),
                _permChip('Users', perms['can_manage_users'] == true),
                _permChip('Notifications', perms['can_send_notifications'] == true),
              ],
            ),
          ],

          if (!isSuperAdmin) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await context.push('/edit_admin_permissions/${admin['id']}');
                    _fetchAdmins();
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Permissions'),
                  style: TextButton.styleFrom(foregroundColor: StitchTheme.primary),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _toggleBlock(admin),
                  icon: Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 16),
                  label: Text(isBlocked ? 'Unblock' : 'Block'),
                  style: TextButton.styleFrom(foregroundColor: isBlocked ? Colors.green : Colors.orange),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _deleteAdmin(admin),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _roleChip(String role) {
    final isSuperAdmin = role == 'super_admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isSuperAdmin ? Colors.amber : StitchTheme.primary).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isSuperAdmin ? Colors.amber : StitchTheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _permChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (active ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (active ? Colors.green : Colors.red).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_rounded : Icons.close_rounded, size: 10, color: active ? Colors.green : Colors.red),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: active ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
