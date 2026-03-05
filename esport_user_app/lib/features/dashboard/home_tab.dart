import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _games = [];
  Map<String, dynamic>? _walletStats;
  Map<String, dynamic>? _appSettings;

  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Parallel fetch games and wallet
      final futures = await Future.wait([
        _supabase.from('games').select('*').eq('is_active', true).order('created_at'),
        _supabase.from('user_wallets').select('deposit_wallet, winning_wallet').eq('user_id', user.id).single(),
        _supabase.from('app_settings').select().limit(1).maybeSingle(),
      ]);

      if (mounted) {
        setState(() {
          _games = List<Map<String, dynamic>>.from(futures[0] as List);
          _walletStats = futures[1] as Map<String, dynamic>;
          _appSettings = futures[2] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load dashboard data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: StitchLoading());
    }

    final totalBalance = ((_walletStats?['deposit_wallet'] ?? 0) + (_walletStats?['winning_wallet'] ?? 0)).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_appSettings != null && _appSettings!['logo_url'] != null && _appSettings!['logo_url'].toString().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(_appSettings!['logo_url'], height: 28, width: 28, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _appSettings?['app_name'] ?? 'Esport Adda', 
              style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold, fontSize: 22)
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('notifications')
                .stream(primaryKey: ['id'])
                .eq('user_id', _supabase.auth.currentUser!.id)
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              int unreadCount = snapshot.data?.where((n) => n['is_read'] != true).length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: StitchTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              backgroundColor: StitchTheme.surfaceHighlight,
              side: BorderSide.none,
              avatar: const Icon(Icons.account_balance_wallet, color: StitchTheme.primary, size: 18),
              label: Text('₹$totalBalance', style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: StitchTheme.primary,
        backgroundColor: StitchTheme.surface,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Announcement Banner
            StitchCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily Showdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                        const SizedBox(height: 8),
                        Text('Join upcoming tournaments and win exciting cash prizes every single day!', style: TextStyle(color: StitchTheme.textMuted.withOpacity(0.8), fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.emoji_events, size: 60, color: StitchTheme.warning),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Games Header
            const Text(
              'Select Game',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: StitchTheme.textMain,
              ),
            ),
            const SizedBox(height: 16),
            
            // Games Grid
            if (_games.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No games available right now.', style: TextStyle(color: StitchTheme.textMuted)),
                ),
              )
            else 
              StitchGrid(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                children: _games.map((game) {
                  return StitchCard(
                    padding: EdgeInsets.zero,
                    onTap: () => context.push('/tournaments/${game['id']}?name=${game['name']}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: game['logo_url'] != null && game['logo_url'].toString().isNotEmpty
                              ? Image.network(
                                  game['logo_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (c,e,s) => Container(
                                    color: StitchTheme.surfaceHighlight,
                                    child: const Icon(Icons.image_not_supported, size: 40, color: StitchTheme.textMuted),
                                  ),
                                )
                              : Container(
                                  color: StitchTheme.surfaceHighlight,
                                  child: const Icon(Icons.sports_esports, size: 50, color: StitchTheme.primary),
                                ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: StitchTheme.surface,
                          child: Text(
                            game['name'],
                            style: const TextStyle(
                              color: StitchTheme.textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ],
                    ),
                  );
                }).toList().cast<Widget>(),
              ),
          ],
        ),
      ),
    );
  }
}
