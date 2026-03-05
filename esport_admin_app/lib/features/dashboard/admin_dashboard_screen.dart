import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _totalUsers = 0;
  int _activeTournaments = 0;
  int _pendingDeposits = 0;
  int _pendingWithdraws = 0;
  int _openTickets = 0;
  Map<String, dynamic>? _appSettings;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    try {
      final futures = await Future.wait<dynamic>([
        _supabase.from('users').select('id').count(CountOption.exact),
        _supabase.from('tournaments').select('id').inFilter('status', ['upcoming', 'ongoing']).count(CountOption.exact),
        _supabase.from('deposit_requests').select('id').eq('status', 'pending').count(CountOption.exact),
        _supabase.from('withdraw_requests').select('id').eq('status', 'pending').count(CountOption.exact),
        _supabase.from('support_tickets').select('id').eq('status', 'open').count(CountOption.exact),
        _supabase.from('app_settings').select().limit(1).maybeSingle(),
      ]);

      if (mounted) {
        setState(() {
          _totalUsers = futures[0].count ?? 0;
          _activeTournaments = futures[1].count ?? 0;
          _pendingDeposits = futures[2].count ?? 0;
          _pendingWithdraws = futures[3].count ?? 0;
          _openTickets = futures[4].count ?? 0;
          _appSettings = futures[5] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_appSettings != null && _appSettings!['admin_logo_url'] != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(_appSettings!['admin_logo_url'], height: 28, width: 28, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _appSettings?['app_name'] ?? 'Admin Dashboard', 
              style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
               await _supabase.auth.signOut();
               if (context.mounted) context.go('/login');
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMetrics,
        color: StitchTheme.primary,
        backgroundColor: StitchTheme.surface,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StitchGrid(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              childAspectRatio: 1.2,
              children: [
                _buildMetricCard('Total Users', _totalUsers.toString(), Icons.people_alt, StitchTheme.primary),
                _buildMetricCard('Active Tournaments', _activeTournaments.toString(), Icons.emoji_events, StitchTheme.warning),
                _buildMetricCard('Pending Deposits', _pendingDeposits.toString(), Icons.download, StitchTheme.success),
                _buildMetricCard('Pending Withdraws', _pendingWithdraws.toString(), Icons.upload, StitchTheme.error),
                _buildMetricCard('Open Support', _openTickets.toString(), Icons.support_agent, StitchTheme.secondary),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Management Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
            const SizedBox(height: 16),
            _buildNavListTile(context, 'Game Management', Icons.sports_esports, '/games'),
            _buildNavListTile(context, 'Tournament Management', Icons.military_tech, '/tournaments'),
            _buildNavListTile(context, 'User Management', Icons.people, '/users'),
            _buildNavListTile(context, 'Deposit Requests', Icons.arrow_circle_down, '/deposits', badge: _pendingDeposits),
            _buildNavListTile(context, 'Withdraw Requests', Icons.arrow_circle_up, '/withdraws', badge: _pendingWithdraws),
            _buildNavListTile(context, 'Support Management', Icons.support_agent, '/support', badge: _openTickets),
            _buildNavListTile(context, 'Notification Center', Icons.campaign, '/send_notification'),
            _buildNavListTile(context, 'Payment Settings', Icons.settings_applications, '/payment_settings'),
            _buildNavListTile(context, 'App Settings', Icons.settings, '/app_settings'),
            _buildNavListTile(context, 'Image Gallery', Icons.collections, '/assets'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return StitchStatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
    );
  }

  Widget _buildNavListTile(BuildContext context, String title, IconData icon, String route, {int badge = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StitchCard(
        onTap: () => context.push(route),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: StitchTheme.textMain),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: StitchBadge(text: badge.toString(), color: StitchTheme.error),
                ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: StitchTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
