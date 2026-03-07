import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class CreateAdminScreen extends StatefulWidget {
  const CreateAdminScreen({Key? key}) : super(key: key);

  @override
  State<CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends State<CreateAdminScreen> {
  final _supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  // Permission toggles
  bool _canManageGames = false;
  bool _canManageTournaments = false;
  bool _canManageResults = false;
  bool _canManageDeposits = false;
  bool _canManageWithdrawals = false;
  bool _canManageUsers = false;
  bool _canSendNotifications = false;
  bool _canViewDashboard = true;

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      StitchSnackbar.showError(context, 'Name, email and password are required');
      return;
    }
    if (password.length < 6) {
      StitchSnackbar.showError(context, 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _supabase.functions.invoke('create_admin', body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        'permissions': {
          'can_manage_games': _canManageGames,
          'can_manage_tournaments': _canManageTournaments,
          'can_manage_results': _canManageResults,
          'can_manage_deposits': _canManageDeposits,
          'can_manage_withdrawals': _canManageWithdrawals,
          'can_manage_users': _canManageUsers,
          'can_send_notifications': _canSendNotifications,
          'can_view_dashboard': _canViewDashboard,
        },
      });

      if (response.data?['error'] != null) {
        throw Exception(response.data['error']);
      }

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Admin created successfully!');
        context.pop();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StitchCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 16),
                  StitchInput(label: 'Full Name', controller: _nameCtrl, hintText: 'e.g. Rahul Sharma', prefixIcon: const Icon(Icons.person_outline)),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, hintText: 'admin@example.com', prefixIcon: const Icon(Icons.email_outlined)),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Password', controller: _passwordCtrl, isPassword: true, hintText: 'Minimum 6 characters', prefixIcon: const Icon(Icons.lock_outline)),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Phone (Optional)', controller: _phoneCtrl, keyboardType: TextInputType.phone, prefixIcon: const Icon(Icons.phone_outlined)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            StitchCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 4),
                  const Text('Select what this admin can access', style: TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
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

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: StitchButton(
                text: 'Create Admin',
                isLoading: _isLoading,
                onPressed: _create,
              ),
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
