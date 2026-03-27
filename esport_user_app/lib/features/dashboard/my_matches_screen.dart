import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyMatchesScreen extends StatefulWidget {
  final bool isBottomNav;
  const MyMatchesScreen({Key? key, this.isBottomNav = false}) : super(key: key);

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _myTeams = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('joined_teams')
          .select('*, tournaments(*, games(name))')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _myTeams = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF13151D),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: TournamentShimmer(),
          ),
        ),
      );
    }

    final upcoming = _myTeams.where((t) => t['tournaments'] != null && t['tournaments']['status'] == 'upcoming').toList();
    final ongoing = _myTeams.where((t) => t['tournaments'] != null && t['tournaments']['status'] == 'ongoing').toList();
    final completed = _myTeams.where((t) => t['tournaments'] != null && t['tournaments']['status'] == 'completed').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF13151D),
      appBar: AppBar(
        title: const Text('MY MATCHES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        centerTitle: true,
        backgroundColor: const Color(0xFF13151D),
        elevation: 0,
        automaticallyImplyLeading: !widget.isBottomNav,
        leading: widget.isBottomNav ? null : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white60,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMatches,
        color: StitchTheme.primary,
        backgroundColor: const Color(0xFF1F222A),
        child: TabBarView(
          controller: _tabController,
          children: [
            _MatchList(matches: upcoming, status: 'upcoming'),
            _MatchList(matches: ongoing, status: 'ongoing'),
            _MatchList(matches: completed, status: 'completed'),
          ],
        ),
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final String status;

  const _MatchList({required this.matches, required this.status});

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();
    
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_esports_outlined, size: 48, color: Colors.white10),
            const SizedBox(height: 16),
            Text('No $status matches found.', style: const TextStyle(color: StitchTheme.textMuted)),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final team = matches[index];
          final t = team['tournaments'];
          final isCompleted = status == 'completed';
          
          if (isCompleted) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _CompletedMatchCard(team: team, tournament: t),
            );
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _MatchCard(
              team: team,
              tournament: t,
              status: status,
            ),
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> team;
  final Map<String, dynamic> tournament;
  final String status;

  const _MatchCard({
    required this.team,
    required this.tournament,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final g = tournament['games'];
    final double progress = (tournament['joined_slots'] ?? 0) / (tournament['total_slots'] ?? 1);
    final isOngoing = status == 'ongoing';

    return GestureDetector(
      onTap: () => context.push('/tournament_detail/${tournament['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F222A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Image Banner with Badges
            Stack(
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: tournament['banner_url'] != null
                      ? CachedNetworkImage(
                          imageUrl: tournament['banner_url'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const StitchShimmer(),
                          errorWidget: (context, url, error) => Container(color: const Color(0xFF2A2D36)),
                        )
                      : Container(color: const Color(0xFF2A2D36)),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.1)],
                      ),
                    ),
                  ),
                ),
                // Badges
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
                    child: Text(tournament['tournament_type'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_rounded, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text(g['name'].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 2. Title and Prize Pool
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tournament['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Prize Pool', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      Text('₹${tournament['total_prize_pool'] ?? 0}', style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  )
                ],
              ),
            ),

            // 3. Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFF2A2D36), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCol('Entry Fee', '₹${tournament['entry_fee']}'),
                    Container(width: 1, height: 30, color: Colors.white10),
                    _buildStatCol('Per Kill', '₹${tournament['per_kill_reward']}'),
                    Container(width: 1, height: 30, color: Colors.white10),
                    _buildStatCol('Type', tournament['tournament_type'].toString().toUpperCase()),
                  ],
                ),
              ),
            ),

            // 4. Room Info (For ongoing)
            if (isOngoing) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      _roomRow('Room ID:', tournament['room_id'] ?? 'Not Ready'),
                      const SizedBox(height: 8),
                      _roomRow('Password:', tournament['room_password'] ?? 'Not Ready'),
                    ],
                  ),
                ),
              ),
            ],

            // 4. Team Details (If Duo/Squad)
            if (team['team_data'] != null && (team['team_data'] as List).length > 1) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TEAM MEMBERS', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      ...(team['team_data'] as List).map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 10, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Text(
                              '${m['name']?.toString().toUpperCase() ?? 'UNK'}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              'UID: ${m['uid'] ?? '-'}',
                              style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              ),
            ],

            // 5. Progress/Status
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Starts: ',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                          children: [
                            TextSpan(
                              text: tournament['start_time'] != null ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(tournament['start_time']).toLocal()) : 'TBD',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      if (isOngoing)
                        const Text('● Live Now', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))
                      else
                        const Text('Starts soon', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(isOngoing ? Colors.redAccent : Colors.blueAccent),
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

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _roomRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace')),
        const Spacer(),
        if (value != 'Not Ready')
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
            },
            child: const Icon(Icons.copy, size: 16, color: Colors.blueAccent),
          ),
      ],
    );
  }
}

class _CompletedMatchCard extends StatelessWidget {
  final Map<String, dynamic> team;
  final Map<String, dynamic> tournament;

  const _CompletedMatchCard({required this.team, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final g = tournament['games'];
    // final bool participated = true; // User obviously participated since it's "My Matches"

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F222A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: tournament['banner_url'] != null
                    ? CachedNetworkImage(imageUrl: tournament['banner_url'], fit: BoxFit.cover)
                    : Container(color: const Color(0xFF2A2D36)),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.3), Colors.transparent, const Color(0xFF1F222A)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white54)),
                  child: const Text('Finished', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
                      child: Text(tournament['tournament_type'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded, color: Colors.white70, size: 10),
                          const SizedBox(width: 4),
                          Text(g['name'].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tournament['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text('My Rank: #${team['rank'] ?? '-'}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF2A2D36), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      const Text('PRIZE POOL', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('₹${tournament['total_prize_pool'] ?? 0}', style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: const Color(0xFF13151D), borderRadius: BorderRadius.circular(24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCol('KILLS', '${team['kills'] ?? 0}', Colors.white),
                  Container(width: 1, height: 24, color: Colors.white10),
                  _buildStatCol('WINNINGS', '₹${team['total_prize'] ?? 0}', Colors.greenAccent),
                  Container(width: 1, height: 24, color: Colors.white10),
                  _buildStatCol('DATE', tournament['start_time'] != null ? DateFormat('MMM dd').format(DateTime.parse(tournament['start_time'])) : 'TBD', Colors.white),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GestureDetector(
              onTap: () => context.push('/match_results/${tournament['id']}'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFF1E50FF), borderRadius: BorderRadius.circular(24)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.leaderboard_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('View Leaderboard', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
