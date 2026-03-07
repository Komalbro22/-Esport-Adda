import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class TournamentListScreen extends StatefulWidget {
  final String gameId;
  final String gameName;

  const TournamentListScreen({Key? key, required this.gameId, required this.gameName}) : super(key: key);

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameName, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
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
      backgroundColor: const Color(0xFF13151D),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TournamentListView(gameId: widget.gameId, status: 'upcoming', gameName: widget.gameName),
          _TournamentListView(gameId: widget.gameId, status: 'ongoing', gameName: widget.gameName),
          _TournamentListView(gameId: widget.gameId, status: 'completed', gameName: widget.gameName),
        ],
      ),
    );
  }
}

class _TournamentListView extends StatefulWidget {
  final String gameId;
  final String status;
  final String gameName;

  const _TournamentListView({Key? key, required this.gameId, required this.status, required this.gameName}) : super(key: key);

  @override
  State<_TournamentListView> createState() => _TournamentListViewState();
}

class _TournamentListViewState extends State<_TournamentListView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tournaments = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTournaments() async {
    try {
      final user = _supabase.auth.currentUser;
      
      if (widget.status == 'completed' && user != null) {
        // Fetch completed tournaments AND the user's specific result for that tournament
        final data = await _supabase.from('tournaments')
            .select('*, joined_teams(user_id, rank, kills, total_prize)')
            .eq('game_id', widget.gameId)
            .eq('status', widget.status)
            .order('start_time', ascending: false);
            
        if (mounted) {
          setState(() {
            _tournaments = List<Map<String, dynamic>>.from(data).map((t) {
              final myTeam = (t['joined_teams'] as List).where((team) => team['user_id'] == user.id).toList();
              t['my_result'] = myTeam.isNotEmpty ? myTeam.first : null;
              return t;
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        // Normal fetch for upcoming/ongoing
        final data = await _supabase
            .from('tournaments')
            .select('*')
            .eq('game_id', widget.gameId)
            .eq('status', widget.status)
            .order('start_time', ascending: widget.status == 'upcoming');
            
        if (mounted) {
          setState(() {
            _tournaments = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: StitchLoading());
    
    if (_tournaments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchTournaments,
        color: StitchTheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note_rounded, size: 48, color: StitchTheme.textMuted.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No ${widget.status} tournaments found.', 
                      style: const TextStyle(color: StitchTheme.textMuted)
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTournaments,
      color: StitchTheme.primary,
      backgroundColor: StitchTheme.surface,
      child: Scrollbar(
        controller: _scrollController,
        child: CustomScrollView(
          controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = _tournaments[index];
                  final double progress = (t['joined_slots'] ?? 0) / (t['total_slots'] ?? 1);
                  final isCompleted = widget.status == 'completed';
                  final isOngoing = widget.status == 'ongoing';
                  
                  if (isCompleted) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _CompletedTournamentCard(tournament: t, gameName: widget.gameName),
                    );
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: GestureDetector(
                      onTap: () => context.push('/tournament_detail/${t['id']}'),
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
                                  child: t['banner_url'] != null && t['banner_url'].toString().isNotEmpty
                                      ? Image.network(
                                          t['banner_url'], 
                                          fit: BoxFit.cover, 
                                          errorBuilder: (c,e,s) => Container(color: const Color(0xFF2A2D36))
                                        )
                                      : Container(
                                          color: const Color(0xFF2A2D36), 
                                          child: const Icon(Icons.sports_esports, size: 40, color: Colors.white30)
                                        ),
                                ),
                                // Gradient Overlay
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.3),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.1),
                                        ],
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
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent, // Use gradient or solid color
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      t['tournament_type'].toString().toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.map_rounded, color: Colors.white70, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.gameName.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      t['title'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Prize Pool',
                                        style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${t['total_prize_pool'] ?? 0}',
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            
                            // 3. Stats Inner Container
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2D36),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatColumn('Entry Fee', '₹${t['entry_fee']}'),
                                    Container(width: 1, height: 30, color: Colors.white10),
                                    _buildStatColumn('Per Kill', '₹${t['per_kill_reward']}'),
                                    Container(width: 1, height: 30, color: Colors.white10),
                                    _buildStatColumn('Type', t['tournament_type'].toString().toUpperCase()),
                                  ],
                                ),
                              ),
                            ),
                            
                            // 4. Progress and Status
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: 'Slots Filled: ',
                                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                                          children: [
                                            TextSpan(
                                              text: '${t['joined_slots']}/${t['total_slots']}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isOngoing)
                                        Text(
                                          'Starts soon', // Could format actual time here
                                          style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                        )
                                      else
                                        const Text(
                                          '● Live Now',
                                          style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: Colors.white10,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        progress >= 1.0 ? Colors.greenAccent : Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _tournaments.length,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _CompletedTournamentCard extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final String gameName;

  const _CompletedTournamentCard({required this.tournament, required this.gameName});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final myResult = t['my_result'];
    final bool participated = myResult != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F222A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Image & Badges
          Stack(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: t['banner_url'] != null && t['banner_url'].toString().isNotEmpty
                    ? Image.network(t['banner_url'], fit: BoxFit.cover)
                    : Container(color: const Color(0xFF2A2D36)),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, const Color(0xFF1F222A)],
                    ),
                  ),
                ),
              ),
              // Finished Badge
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white54),
                  ),
                  child: const Text('Finished', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              // Type / Map Badge
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
                      child: Text(t['tournament_type'].toString().capitalize(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded, color: Colors.white70, size: 10),
                          const SizedBox(width: 4),
                          Text(gameName, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Title & Rank / Prize Pool
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      if (participated)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.green, size: 14),
                              const SizedBox(width: 4),
                              Text('My Rank: #${myResult['rank'] ?? '-'}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Did not participate', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2D36),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text('PRIZE POOL', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('₹${t['total_prize_pool'] ?? 0}', style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF13151D),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn(participated ? 'KILLS' : 'ENTRY', participated ? '${myResult['kills'] ?? 0}' : '₹${t['entry_fee']}', Colors.white),
                  Container(width: 1, height: 24, color: Colors.white10),
                  _buildStatColumn(participated ? 'WINNINGS' : 'SLOTS', participated ? '₹${myResult['total_prize'] ?? 0}' : '${t['joined_slots']}/${t['total_slots']}', Colors.greenAccent),
                  Container(width: 1, height: 24, color: Colors.white10),
                  _buildStatColumn('DATE', _formatDate(t['start_time']), Colors.white),
                ],
              ),
            ),
          ),
          
          // View Leaderboard Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GestureDetector(
               onTap: () => context.push('/match_results/${t['id']}'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E50FF),
                  borderRadius: BorderRadius.circular(24),
                ),
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

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'TBD';
    final date = DateTime.parse(isoString).toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

