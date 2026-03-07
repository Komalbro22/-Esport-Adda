import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class EditAdminPermissionsScreen extends StatefulWidget {
  final String userId;
  const EditAdminPermissionsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<EditAdminPermissionsScreen> createState() => _EditAdminPermissionsScreenState();
}

class _EditAdminPermissionsScreenState extends State<EditAdminPermissionsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  String _adminName = '';

  bool _canManageGames = false;
  bool _canManageTournaments = false;
  bool _canManageResults = false;
  bool _canManageDeposits = false;
  bool _canManageWithdrawals = false;
  bool _canManageUsers = false;
  bool _canSendNotifications = false;
  bool _canViewDashboard = true;

  @override
  void initState() {
    super.initState();
    _fetchPerms();
  }

  Future<void> _fetchPerms() async {
    try {
      final user = await _supabase.from('users').select('name').eq('id', widget.userId).single();
      final perms = await _supabase
          .from('admin_permissions')
          .select()
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _adminName = user['name'] ?? 'Admin';
          if (perms != null) {
            _canManageGames = perms['can_manage_games'] ?? false;
            _canManageTournaments = perms['can_manage_tournaments'] ?? false;
            _canManageResults = perms['can_manage_results'] ?? false;
            _canManageDeposits = perms['can_manage_deposits'] ?? false;
            _canManageWithdrawals = perms['can_manage_withdrawals'] ?? false;
            _canManageUsers = perms['can_manage_users'] ?? false;
            _canSendNotifications = perms['can_send_notifications'] ?? false;
            _canViewDashboard = perms['can_view_dashboard'] ?? true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _supabase.from('admin_permissions').upsert({
        'user_id': widget.userId,
        'can_manage_games': _canManageGames,
        'can_manage_tournaments': _canManageTournaments,
        'can_manage_results': _canManageResults,
        'can_manage_deposits': _canManageDeposits,
        'can_manage_withdrawals': _canManageWithdrawals,
        'can_manage_users': _canManageUsers,
        'can_send_notifications': _canSendNotifications,
        'can_view_dashboard': _canViewDashboard,
      });

      await AdminLogService.log(
        action: 'edit_admin_permissions',
        targetType: 'user',
        targetId: widget.userId,
        details: {
          'can_manage_games': _canManageGames,
          'can_manage_tournaments': _canManageTournaments,
          'can_manage_results': _canManageResults,
          'can_manage_deposits': _canManageDeposits,
          'can_manage_withdrawals': _canManageWithdrawals,
          'can_manage_users': _canManageUsers,
          'can_send_notifications': _canSendNotifications,
        },
      );

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Permissions saved for $_adminName');
        context.pop();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to save permissions');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());

    return Scaffold(
      appBar: AppBar(title: Text('Permissions — $_adminName')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            StitchCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Feature Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 4),
                  Text('Editing permissions for $_adminName', style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
                  const SizedBox(height: 16),
                  _buildToggle('Manage Games', Icons.sports_esports_rounded, _canManageGames, (v) => setState(() => _canManageGames = v)),
                  _buildToggle('Manage Tournaments', Icons.military_tech_rounded, _canManageTournaments, (v) => setState(() => _canManageTournaments = v)),
                  _buildToggle('Manage Results', Icons.leaderboard_rounded, _canManageResults, (v) => setState(() => _canManageResults = v)),
                  _buildToggle('Manage Deposits', Icons.add_circle_outline_rounded, _canManageDeposits, (v) => setState(() => _canManageDeposits = v)),
                  _buildToggle('Manage Withdrawals', Icons.remove_circle_outline_rounded, _canManageWithdrawals, (v) => setState(() => _canManageWithdrawals = v)),
                  _buildToggle('Manage Users', Icons.group_rounded, _canManageUsers, (v) => setState(() => _canManageUsers = v)),
                  _buildToggle('Send Notifications', Icons.notifications_rounded, _canSendNotifications, (v) => setState(() => _canSendNotifications = v)),
                  _buildToggle('View Dashboard', Icons.dashboard_rounded, _canViewDashboard, (v) => setState(() => _canViewDashboard = v)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: StitchButton(text: 'Save Permissions', isLoading: _isSaving, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? StitchTheme.primary.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? StitchTheme.primary.withOpacity(0.2) : StitchTheme.surfaceHighlight),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        secondary: Icon(icon, size: 20, color: value ? StitchTheme.primary : StitchTheme.textMuted),
        title: Text(label, style: TextStyle(fontSize: 14, color: value ? StitchTheme.textMain : StitchTheme.textMuted, fontWeight: value ? FontWeight.w600 : FontWeight.normal)),
        value: value,
        onChanged: onChanged,
        activeColor: StitchTheme.primary,
      ),
    );
  }
}
