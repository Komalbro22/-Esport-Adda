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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _featuredTournaments = [];

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final futures = await Future.wait([
        _supabase.from('games').select('*').eq('is_active', true).order('created_at'),
        _supabase.from('user_wallets').select('deposit_wallet, winning_wallet').eq('user_id', user.id).single(),
        _supabase.from('app_settings').select().limit(1).maybeSingle(),
        _supabase.from('tournaments')
            .select('*, games(name)')
            .eq('status', 'upcoming')
            .order('start_time', ascending: true)
            .limit(5),
      ]);

      if (mounted) {
        setState(() {
          _games = List<Map<String, dynamic>>.from(futures[0] as List);
          _walletStats = futures[1] as Map<String, dynamic>;
          _appSettings = futures[2] as Map<String, dynamic>?;
          _featuredTournaments = List<Map<String, dynamic>>.from(futures[3] as List);
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
            if (_appSettings != null && _appSettings!['logo_url'] != null) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: StitchTheme.primary.withOpacity(0.2), blurRadius: 10)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(_appSettings!['logo_url'], height: 32, width: 32, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              _appSettings?['app_name'] ?? 'Esport Adda', 
              style: const TextStyle(
                color: StitchTheme.textMain, 
                fontWeight: FontWeight.w900, 
                fontSize: 24,
                letterSpacing: -1,
              )
            ),
          ],
        ),
        actions: [
          _buildNotificationIcon(),
          const SizedBox(width: 8),
          _buildWalletChip(totalBalance),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              StitchTheme.secondary.withOpacity(0.05),
              StitchTheme.background,
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: StitchTheme.primary,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 80, 16, 16),
            children: [
              // Hero Banner
              _buildHeroBanner(),
              
              const SizedBox(height: 24),
              
              // Featured Header
              if (_featuredTournaments.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.star_rounded, color: StitchTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'FEATURED TOURNAMENTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: StitchTheme.textMain,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _featuredTournaments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final t = _featuredTournaments[index];
                      return _buildFeaturedCard(t);
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              const Row(
                children: [
                  Icon(Icons.grid_view_rounded, color: StitchTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'EXPLORE GAMES',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: StitchTheme.textMain,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Games Grid - Fixed 2 columns for mobile feel
              if (_games.isEmpty)
                _buildEmptyState()
              else 
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _games.length,
                  itemBuilder: (context, index) {
                    final game = _games[index];
                    return _buildGameCard(game);
                  },
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                                                    
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        int unreadCount = snapshot.data?.where((n) => n['is_read'] != true).length ?? 0;
        return IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_none_rounded, size: 28),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 14,
                    width: 14,
                    decoration: BoxDecoration(
                      color: StitchTheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: StitchTheme.background, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => context.push('/notifications'),
        );
      },
    );
  }

  Widget _buildWalletChip(String balance) {
    return GestureDetector(
      onTap: () => context.push('/wallet'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: StitchTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              '₹$balance',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            StitchTheme.primary.withOpacity(0.2),
            StitchTheme.secondary.withOpacity(0.2),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.3,
              child: Icon(Icons.emoji_events_rounded, size: 180, color: StitchTheme.primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: StitchTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MEGA EVENT',
                    style: TextStyle(color: StitchTheme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Daily Showdown',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join tournaments & win big prizes!',
                  style: TextStyle(color: StitchTheme.textMuted.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(delay: 200.ms);
  }

  Widget _buildFeaturedCard(Map<String, dynamic> t) {
    return GestureDetector(
      onTap: () => context.push('/tournament_detail/${t['id']}'),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: StitchTheme.surface,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            t['banner_url'] != null
                ? Image.network(t['banner_url'], fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                : Container(color: StitchTheme.surfaceHighlight),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: StitchTheme.primary.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t['games']['name'].toString().toUpperCase(),
                      style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t['title'],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.payments_rounded, color: StitchTheme.success, size: 14),
                      const SizedBox(width: 4),
                      Text('₹${t['entry_fee']}', style: const TextStyle(color: StitchTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
                      const Spacer(),
                      Text('${t['joined_slots']}/${t['total_slots']} FILLED', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    return GestureDetector(
      onTap: () => context.push('/tournaments/${game['id']}?name=${game['name']}'),
      child: Container(
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  game['logo_url'] != null
                      ? Image.network(game['logo_url'], fit: BoxFit.cover)
                      : Container(color: StitchTheme.surfaceHighlight, child: const Icon(Icons.sports_esports, color: StitchTheme.primary, size: 40)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Text(
                  game['name'].toString().toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
       .shimmer(delay: 2.seconds, duration: 2.seconds, color: Colors.white.withOpacity(0.05)),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48.0),
        child: Column(
          children: [
            Icon(Icons.videogame_asset_off_rounded, size: 64, color: Colors.white10),
            SizedBox(height: 16),
            Text('No games available right now.', style: TextStyle(color: StitchTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
