import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _games = [];
  List<Map<String, dynamic>> _featuredTournaments = [];
  
  // Performance: Using ValueNotifier for granular updates
  final ValueNotifier<Map<String, dynamic>?> _walletStatsNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  
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
            .eq('is_featured', true)
            .eq('status', 'upcoming')
            .order('start_time', ascending: true)
            .limit(5),
      ]);

      if (mounted) {
        setState(() {
          _games = List<Map<String, dynamic>>.from(futures[0] as List);
          // _appSettings = futures[2] as Map<String, dynamic>?; // Removed unused _appSettings
          _featuredTournaments = List<Map<String, dynamic>>.from(futures[3] as List);
          _isLoading = false;
        });
        // Update wallet separately via notifier to avoid full rebuild
        _walletStatsNotifier.value = futures[1] as Map<String, dynamic>;
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
      return Scaffold(
        backgroundColor: StitchTheme.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StitchShimmer.circular(size: 44),
                    const Spacer(),
                    StitchShimmer.circular(size: 40),
                    const SizedBox(width: 16),
                    StitchShimmer.rectangular(width: 100, height: 48, borderRadius: BorderRadius.circular(24)),
                  ],
                ),
                const SizedBox(height: 32),
                StitchShimmer.rectangular(width: 200, height: 24),
                const SizedBox(height: 20),
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, __) => StitchShimmer.rectangular(width: 320, height: 190, borderRadius: BorderRadius.circular(24)),
                  ),
                ),
                const SizedBox(height: 32),
                StitchShimmer.rectangular(width: 150, height: 24),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 4,
                  itemBuilder: (_, __) => StitchShimmer.rectangular(height: 180, borderRadius: BorderRadius.circular(24)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: StitchTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: StitchTheme.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Custom Header
                    ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: _walletStatsNotifier,
                      builder: (context, stats, _) {
                        final balance = ((stats?['deposit_wallet'] ?? 0) + (stats?['winning_wallet'] ?? 0)).toStringAsFixed(2);
                        return _buildHeader(balance);
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Featured Tournament Section
                    if (_featuredTournaments.isNotEmpty) ...[
                      const Text(
                        'Featured Tournament',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: StitchTheme.textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _featuredTournaments.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            return _buildFeaturedCard(_featuredTournaments[index]);
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    
                    const Text(
                      'Explore Games',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: StitchTheme.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
              
              // Games Grid using SliverGrid for optimization
              if (_games.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else 
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildGameCard(_games[index]);
                      },
                      childCount: _games.length,
                    ),
                  ),
                ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String balance) {
    return Row(
      children: [
        // Profile Avatar
        GestureDetector(
          onTap: () => context.push('/edit_profile'),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: StitchTheme.primaryGradient,
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: StitchTheme.surface,
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
        const Spacer(),
        // Notification Icon
        _buildNotificationButton(),
        const SizedBox(width: 16),
        // Wallet Pill
        _buildWalletPill(balance),
      ],
    );
  }

  Widget _buildNotificationButton() {
    return Container(
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: IconButton(
        icon: const Icon(Icons.notifications_rounded, color: Color(0xFF94A3B8), size: 22),
        onPressed: () => context.push('/notifications'),
      ),
    );
  }

  Widget _buildWalletPill(String balance) {
    return GestureDetector(
      onTap: () => context.push('/wallet'),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: StitchTheme.primary.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: StitchTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              '₹$balance',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFeaturedCard(Map<String, dynamic> t) {
    final double progress = (t['joined_slots'] ?? 0) / (t['total_slots'] ?? 1);
    
    return GestureDetector(
      onTap: () => context.push('/tournament_detail/${t['id']}'),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: StitchTheme.primary.withValues(alpha: 0.5), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Image
            if (t['banner_url'] != null)
              CachedNetworkImage(
                imageUrl: t['banner_url'],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const StitchShimmer(),
                errorWidget: (context, url, error) => Container(color: StitchTheme.surfaceHighlight),
              )
            else
              Container(color: StitchTheme.surfaceHighlight),
            
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            
            // Logo watermark if available (Using game name as text for now to match style if logo missing)
            Positioned(
              top: 16,
              right: 16,
              child: Opacity(
                opacity: 0.8,
                child: Text(
                  t['games']['name'].toString().toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tournament',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t['title'].toString().toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Entry Fee: ₹${t['entry_fee']}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${t['joined_slots']}/${t['total_slots']} FILLED',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(StitchTheme.primary),
                      ),
                    ),
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
    final bool challengeEnabled = game['challenge_enabled'] == true;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: StitchTheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          GestureDetector(
            onTap: () => context.push('/tournaments/${game['id']}?name=${game['name']}'),
            child: game['logo_url'] != null
                ? CachedNetworkImage(
                    imageUrl: game['logo_url'],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const StitchShimmer(),
                    errorWidget: (context, url, error) => Container(color: StitchTheme.surfaceHighlight),
                  )
                : Container(color: StitchTheme.surfaceHighlight),
          ),
          
          // Dark Overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
            ),
          ),
          
          // Challenge Badge if enabled
          if (challengeEnabled)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => context.push('/tournaments/${game['id']}?name=${game['name']}&tab=3'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.deepPurpleAccent.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.bolt_rounded, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text('CHALLENGES', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
          
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    game['name'].toString().toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.5), size: 12),
              ],
            ),
          ),
        ],
      ),
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
