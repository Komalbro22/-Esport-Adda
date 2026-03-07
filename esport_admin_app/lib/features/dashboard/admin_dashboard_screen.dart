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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                StitchTheme.background.withOpacity(0.9),
                StitchTheme.background.withOpacity(0.0),
              ],
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_appSettings != null && _appSettings!['admin_logo_url'] != null) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: StitchTheme.primary.withOpacity(0.2), blurRadius: 10)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(_appSettings!['admin_logo_url'], height: 32, width: 32, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              _appSettings?['app_name'] ?? 'ESPORT ADMIN', 
              style: const TextStyle(
                color: StitchTheme.textMain, 
                fontWeight: FontWeight.w900, 
                fontSize: 22,
                letterSpacing: -0.5,
              )
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: StitchTheme.error),
            onPressed: () async {
                AdminPermissionService.clear();
                await _supabase.auth.signOut();
               if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              StitchTheme.primary.withOpacity(0.05),
              StitchTheme.background,
              StitchTheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth > 1000 ? 1000 : constraints.maxWidth;
            final ScrollController scrollController = ScrollController();
            
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: RefreshIndicator(
                    onRefresh: _fetchMetrics,
                    color: StitchTheme.primary,
                    child: ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 80, 20, 40),
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.analytics_rounded, color: StitchTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'SYSTEM OVERVIEW',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: StitchTheme.textMuted,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        StitchGrid(
                          crossAxisCount: constraints.maxWidth > 800 ? 5 : (constraints.maxWidth > 500 ? 3 : 2),
                          childAspectRatio: 1.1,
                          children: [
                            _buildModernStat('USERS', _totalUsers.toString(), Icons.people_rounded, StitchTheme.primary, onTap: () => context.push('/users')),
                            _buildModernStat('ACTIVE', _activeTournaments.toString(), Icons.emoji_events_rounded, StitchTheme.warning, onTap: () => context.push('/tournaments')),
                            _buildModernStat('DEPOSITS', _pendingDeposits.toString(), Icons.add_circle_outline_rounded, StitchTheme.success, highlight: _pendingDeposits > 0, onTap: () => context.push('/finances?tab=0')),
                            _buildModernStat('WITHDRAWS', _pendingWithdraws.toString(), Icons.remove_circle_outline_rounded, StitchTheme.error, highlight: _pendingWithdraws > 0, onTap: () => context.push('/finances?tab=1')),
                            _buildModernStat('TICKETS', _openTickets.toString(), Icons.message_rounded, StitchTheme.accent, highlight: _openTickets > 0, onTap: () => context.push('/support')),
                          ],
                        ),
                        
                        const SizedBox(height: 48),
                        
                        const Text(
                          'CORE OPERATIONS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: StitchTheme.textMuted,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: constraints.maxWidth > 800 ? 3 : 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 2.2,
                          children: [
                            _buildNavCard('GAMES', Icons.sports_esports_rounded, '/games'),
                            _buildNavCard('TOURNAMENTS', Icons.military_tech_rounded, '/tournaments'),
                            _buildNavCard('PLAYERS', Icons.group_rounded, '/users'),
                            _buildNavCard('FINANCES', Icons.account_balance_rounded, '/finances'),
                            _buildNavCard('SUPPORT', Icons.support_agent_rounded, '/support', badge: _openTickets),
                            _buildNavCard('COMMUNITY', Icons.campaign_rounded, '/send_notification'),
                            if (AdminPermissionService.isSuperAdmin)
                              _buildNavCard('ADMINS', Icons.shield_rounded, '/admin_management', color: Colors.amber),
                          ],
                        ),
                        
                        const SizedBox(height: 48),
                        
                        const Text(
                          'SYSTEM SETTINGS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: StitchTheme.textMuted,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildSimpleNavTile('Payment Integration', Icons.payments_rounded, '/payment_settings'),
                        _buildSimpleNavTile('Branding & Configuration', Icons.auto_awesome_rounded, '/app_settings'),
                        _buildSimpleNavTile('Cloud Asset Gallery', Icons.cloud_done_rounded, '/assets'),
                        
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildModernStat(String label, String value, IconData icon, Color color, {bool highlight = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: highlight ? color.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
          boxShadow: [
            if (highlight) BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.withOpacity(0.8), size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: StitchTheme.textMuted.withOpacity(0.6), letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard(String label, IconData icon, String route, {int badge = 0, Color? color}) {
    final cardColor = color ?? StitchTheme.primary;
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color != null ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cardColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5, color: color),
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: StitchTheme.error, borderRadius: BorderRadius.circular(10)),
                child: Text(badge.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleNavTile(String title, IconData icon, String route) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.03)),
          ),
          child: Row(
            children: [
              Icon(icon, color: StitchTheme.textMuted, size: 20),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Colors.white10),
            ],
          ),
        ),
      ),
    );
  }
}
