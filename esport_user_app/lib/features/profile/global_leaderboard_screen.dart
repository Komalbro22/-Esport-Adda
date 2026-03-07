import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlobalLeaderboardScreen extends StatefulWidget {
  final bool isBottomNav;
  const GlobalLeaderboardScreen({Key? key, this.isBottomNav = false}) : super(key: key);

  @override
  State<GlobalLeaderboardScreen> createState() => _GlobalLeaderboardScreenState();
}

class _GlobalLeaderboardScreenState extends State<GlobalLeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Key: user_id, Value: Map of stats and user info
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic>? _currentUserStats;
  int _currentUserRank = 0;
  int _displayLimit = 50;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_sortAndSetRank);
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Grouping data locally since Supabase REST API doesn't support GROUP BY easily without views/RPCs
      // This is okay for moderate data sizes. For massive DBs, a backend RPC/View is recommended.
      final futures = await Future.wait<dynamic>([
        _supabase.from('app_settings').select('leaderboard_limit').limit(1).maybeSingle(),
        _supabase.from('joined_teams')
            .select('user_id, rank, kills, total_prize, users:user_id(name, avatar_url)')
            .not('rank', 'is', null),
      ]);

      final settings = futures[0] as Map<String, dynamic>?;
      if (settings != null) {
        _displayLimit = settings['leaderboard_limit'] ?? 50;
      }
      
      final response = futures[1] as List;

      final Map<String, Map<String, dynamic>> userAggregates = {};

      for (var row in response) {
        final userId = row['user_id'] as String;
        final kills = (row['kills'] as num?)?.toInt() ?? 0;
        final prize = (row['total_prize'] as num?)?.toDouble() ?? 0.0;
        final isWin = row['rank'] == 1;

        if (!userAggregates.containsKey(userId)) {
          final userInfo = row['users'] is Map ? row['users'] as Map<String, dynamic> : {};
          userAggregates[userId] = {
            'user_id': userId,
            'name': userInfo['name'] ?? 'Unknown Player',
            'avatar_url': userInfo['avatar_url'],
            'total_kills': 0,
            'total_prize': 0.0,
            'total_wins': 0,
          };
        }

        userAggregates[userId]!['total_kills'] += kills;
        userAggregates[userId]!['total_prize'] += prize;
        if (isWin) {
          userAggregates[userId]!['total_wins'] += 1;
        }
      }

      // Add users who might not have played any match to the bottom (optional but good for current user)
      if (!userAggregates.containsKey(user.id)) {
        final me = await _supabase.from('users').select('name, avatar_url').eq('id', user.id).single();
         userAggregates[user.id] = {
            'user_id': user.id,
            'name': me['name'] ?? 'You',
            'avatar_url': me['avatar_url'],
            'total_kills': 0,
            'total_prize': 0.0,
            'total_wins': 0,
          };
      }

      if (mounted) {
        setState(() {
          var allPlayers = userAggregates.values.toList();
          
          // Sort first to find true ranks
          _sortPlayers(allPlayers);
          
          // Save reference to current user stats before limiting
          if (user != null) {
            final myIndex = allPlayers.indexWhere((e) => e['user_id'] == user.id);
            if (myIndex != -1) {
              _currentUserStats = allPlayers[myIndex];
              _currentUserRank = myIndex + 1;
            }
          }

          // Apply limit
          _leaderboard = allPlayers.take(_displayLimit).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortPlayers(List<Map<String, dynamic>> players) {
    if (players.isEmpty) return;
    final int sortIndex = _tabController.index;

    players.sort((a, b) {
       switch (sortIndex) {
         case 0: // Winnings
           return (b['total_prize'] as num).compareTo(a['total_prize'] as num);
         case 1: // Kills
           return (b['total_kills'] as int).compareTo(a['total_kills'] as int);
         case 2: // Wins
           return (b['total_wins'] as int).compareTo(a['total_wins'] as int);
         default:
           return 0;
       }
    });
  }

  void _sortAndSetRank() {
    _sortPlayers(_leaderboard);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Separate podium from rest
    final podiumRows = _leaderboard.take(3).toList();
    final remainingRows = _leaderboard.skip(3).toList();

    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('GLOBAL RANKING', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        centerTitle: true,
        automaticallyImplyLeading: !widget.isBottomNav,
        leading: widget.isBottomNav ? null : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StitchTheme.primary,
          indicatorWeight: 3,
          labelColor: StitchTheme.primary,
          unselectedLabelColor: StitchTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          tabs: const [
            Tab(text: 'Winnings'),
            Tab(text: 'Kills'),
            Tab(text: 'Wins'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : RefreshIndicator(
              onRefresh: _fetchLeaderboard,
              color: StitchTheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Podium Section
                  if (podiumRows.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: _PodiumView(
                          topPlayers: podiumRows,
                          sortIndex: _tabController.index,
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
                    ),
                  
                  // List Section
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _LeaderboardRow(
                            player: remainingRows[index],
                            rank: index + 4,
                            sortIndex: _tabController.index,
                            isCurrentUser: remainingRows[index]['user_id'] == _supabase.auth.currentUser?.id,
                          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                        },
                        childCount: remainingRows.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomSheet: _currentUserStats != null
          ? _StickyBottomBar(
              player: _currentUserStats!,
              rank: _currentUserRank,
              sortIndex: _tabController.index,
            ).animate().slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOut)
          : null,
    );
  }
}

class _PodiumView extends StatelessWidget {
  final List<Map<String, dynamic>> topPlayers;
  final int sortIndex;

  const _PodiumView({required this.topPlayers, required this.sortIndex});

  @override
  Widget build(BuildContext context) {
    // Order: 2nd, 1st, 3rd for visual podium
    final first = topPlayers[0];
    final second = topPlayers.length > 1 ? topPlayers[1] : null;
    final third = topPlayers.length > 2 ? topPlayers[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (second != null)
          _PodiumSpot(player: second, rank: 2, sortIndex: sortIndex, height: 160),
        const SizedBox(width: 8),
        _PodiumSpot(player: first, rank: 1, sortIndex: sortIndex, height: 200),
        const SizedBox(width: 8),
        if (third != null)
          _PodiumSpot(player: third, rank: 3, sortIndex: sortIndex, height: 140),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final Map<String, dynamic> player;
  final int rank;
  final int sortIndex;
  final double height;

  const _PodiumSpot({
    required this.player,
    required this.rank,
    required this.sortIndex,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    Color medalColor;
    double avatarSize;
    
    switch (rank) {
      case 1:
        medalColor = const Color(0xFFFFD700);
        avatarSize = 44;
        break;
      case 2:
        medalColor = const Color(0xFFE2E8F0);
        avatarSize = 36;
        break;
      default:
        medalColor = const Color(0xFFCD7F32);
        avatarSize = 32;
    }

    String statText = '';
    switch (sortIndex) {
      case 0: statText = '₹${(player['total_prize'] as num).toInt()}'; break;
      case 1: statText = '${player['total_kills']} pts'; break;
      case 2: statText = '${player['total_wins']} wins'; break;
    }

    return SizedBox(
      width: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: medalColor, width: rank == 1 ? 3 : 2),
                  boxShadow: [
                    BoxShadow(color: medalColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)
                  ],
                ),
                child: CircleAvatar(
                  radius: avatarSize,
                  backgroundColor: StitchTheme.surface,
                  backgroundImage: player['avatar_url'] != null ? NetworkImage(player['avatar_url']) : null,
                  child: player['avatar_url'] == null ? const Icon(Icons.person, color: StitchTheme.textMuted) : null,
                ),
              ),
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: medalColor, shape: BoxShape.circle),
                  child: Text(
                    rank.toString(),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            player['name'],
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            statText,
            style: TextStyle(color: medalColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          // Podium Base
          Container(
            height: height - 100,
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  StitchTheme.surfaceHighlight.withOpacity(0.5),
                  StitchTheme.surfaceHighlight.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final Map<String, dynamic> player;
  final int rank;
  final int sortIndex;
  final bool isCurrentUser;

  const _LeaderboardRow({
    required this.player,
    required this.rank,
    required this.sortIndex,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    String statText = '';
    switch (sortIndex) {
      case 0: statText = '₹${(player['total_prize'] as num).toInt()}'; break;
      case 1: statText = '${player['total_kills']}'; break;
      case 2: statText = '${player['total_wins']}'; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? StitchTheme.primary.withOpacity(0.05) : StitchTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentUser ? StitchTheme.primary.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              rank.toString(),
              style: const TextStyle(color: StitchTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
          
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: StitchTheme.surfaceHighlight, width: 1.5),
            ),
            child: CircleAvatar(
              backgroundColor: StitchTheme.surfaceHighlight,
              backgroundImage: player['avatar_url'] != null ? NetworkImage(player['avatar_url']) : null,
              child: player['avatar_url'] == null 
                  ? const Icon(Icons.person, size: 20, color: StitchTheme.textMuted) 
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          
          // Name 
          Expanded(
            child: Text(
              isCurrentUser ? '${player['name']} (You)' : player['name'],
              style: TextStyle(
                color: isCurrentUser ? StitchTheme.primary : StitchTheme.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Stat
          Text(
            statText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  final Map<String, dynamic> player;
  final int rank;
  final int sortIndex;

  const _StickyBottomBar({
    required this.player,
    required this.rank,
    required this.sortIndex,
  });

  @override
  Widget build(BuildContext context) {
    String statText = '';
    switch (sortIndex) {
      case 0: statText = '₹${(player['total_prize'] as num).toInt()}'; break;
      case 1: statText = '${player['total_kills']}'; break;
      case 2: statText = '${player['total_wins']}'; break;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13151D),
        border: Border(top: BorderSide(color: StitchTheme.primary.withOpacity(0.2), width: 1.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(0, -5), blurRadius: 20)
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Text(rank.toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(width: 16),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: StitchTheme.primary, width: 2)),
            child: CircleAvatar(
              backgroundColor: StitchTheme.surfaceHighlight,
              backgroundImage: player['avatar_url'] != null ? NetworkImage(player['avatar_url']) : null,
              child: player['avatar_url'] == null 
                  ? const Icon(Icons.person, size: 24, color: StitchTheme.textMuted) 
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${player['name']} (You)', 
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                Text('YOUR CURRENT RANK', 
                  style: TextStyle(color: StitchTheme.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
          Text(statText, 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
