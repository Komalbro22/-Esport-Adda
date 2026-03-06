import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class GlobalLeaderboardScreen extends StatefulWidget {
  const GlobalLeaderboardScreen({Key? key}) : super(key: key);

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
      final response = await _supabase
          .from('joined_teams')
          .select('user_id, rank, kills, total_prize, users:user_id(name, avatar_url)')
          .not('rank', 'is', null);

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
          _leaderboard = userAggregates.values.toList();
          _sortAndSetRank();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortAndSetRank() {
    if (_leaderboard.isEmpty) return;

    final user = _supabase.auth.currentUser;
    final int sortIndex = _tabController.index;

    _leaderboard.sort((a, b) {
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

    if (user != null) {
      final myIndex = _leaderboard.indexWhere((e) => e['user_id'] == user.id);
      if (myIndex != -1) {
        _currentUserStats = _leaderboard[myIndex];
        _currentUserRank = myIndex + 1;
      }
    }
    
    // Only setState if the tab is changing, not on initial load (which is handled in _fetchLeaderboard)
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('Global Leaderboard', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchLeaderboard,
                    color: StitchTheme.primary,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // padding bottom for sticky bar
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, index) {
                        return _LeaderboardRow(
                          player: _leaderboard[index],
                          rank: index + 1,
                          sortIndex: _tabController.index,
                          isCurrentUser: _leaderboard[index]['user_id'] == _supabase.auth.currentUser?.id,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      bottomSheet: _currentUserStats != null
          ? _StickyBottomBar(
              player: _currentUserStats!,
              rank: _currentUserRank,
              sortIndex: _tabController.index,
            )
          : null,
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
    Color outlineColor = Colors.transparent;
    Color iconColor = Colors.transparent;
    IconData? rankIcon;

    if (rank == 1) {
      outlineColor = const Color(0xFFFFD700); // Gold
      iconColor = const Color(0xFFFFD700);
      rankIcon = Icons.military_tech;
    } else if (rank == 2) {
      outlineColor = const Color(0xFFC0C0C0); // Silver
      iconColor = const Color(0xFFC0C0C0);
      rankIcon = Icons.military_tech;
    } else if (rank == 3) {
      outlineColor = const Color(0xFFCD7F32); // Bronze
      iconColor = const Color(0xFFCD7F32);
      rankIcon = Icons.military_tech;
    }

    final isPodium = rank <= 3;
    final rowColor = isPodium 
        ? StitchTheme.primary.withOpacity(0.15) 
        : (isCurrentUser ? StitchTheme.surfaceHighlight : Colors.transparent);

    String statText = '';
    switch (sortIndex) {
      case 0:
        statText = '₹${(player['total_prize'] as num).toInt()}';
        break;
      case 1:
        statText = '${player['total_kills']}';
        break;
      case 2:
        statText = '${player['total_wins']}';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPodium ? outlineColor.withOpacity(0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank Column
          SizedBox(
            width: 40,
            child: Center(
              child: isPodium
                  ? Icon(rankIcon, color: iconColor, size: 28)
                  : Text(
                      rank.toString(),
                      style: const TextStyle(color: StitchTheme.textMuted, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isPodium ? outlineColor : StitchTheme.surfaceHighlight, width: 2),
            ),
            child: CircleAvatar(
              backgroundColor: StitchTheme.surfaceHighlight,
              backgroundImage: player['avatar_url'] != null ? NetworkImage(player['avatar_url']) : null,
              child: player['avatar_url'] == null 
                  ? const Icon(Icons.person, size: 24, color: StitchTheme.textMuted) 
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          
          // Name and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '${player['name']} (You)' : player['name'],
                  style: TextStyle(
                    color: isPodium ? StitchTheme.primary : StitchTheme.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Matches Played: ${player['total_kills'] > 0 || player['total_prize'] > 0 ? "Yes" : "0"}', // Basic stat subtext
                  style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          
          // Primary Stat
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
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
      case 0:
        statText = '₹${(player['total_prize'] as num).toInt()}';
        break;
      case 1:
        statText = '${player['total_kills']}';
        break;
      case 2:
        statText = '${player['total_wins']}';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2129),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(0, -5),
            blurRadius: 20,
          )
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Text(
                rank.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: StitchTheme.primary, width: 2)),
            child: CircleAvatar(
              backgroundColor: StitchTheme.surfaceHighlight,
              backgroundImage: player['avatar_url'] != null ? NetworkImage(player['avatar_url']) : null,
              child: player['avatar_url'] == null 
                  ? const Icon(Icons.person, size: 24, color: StitchTheme.textMuted) 
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player['name']} (You)',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Text(
                  'YOUR RANKING',
                  style: TextStyle(color: StitchTheme.primary.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ),
          Text(
            statText,
            style: const TextStyle(color: StitchTheme.success, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
