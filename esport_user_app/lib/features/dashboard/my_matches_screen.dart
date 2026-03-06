import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({Key? key}) : super(key: key);

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
    if (_isLoading) return const Scaffold(body: StitchLoading());

    final upcoming = _myTeams.where((t) => t['tournaments'] != null && t['tournaments']['status'] == 'upcoming').toList();
    final ongoing = _myTeams.where((t) => t['tournaments'] != null && t['tournaments']['status'] == 'ongoing').toList();
    final completed = _myTeams.where((t) => t['tournaments'] != null && t['tournaments']['status'] == 'completed').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MY MATCHES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StitchTheme.primary,
          indicatorWeight: 3,
          labelColor: StitchTheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
          unselectedLabelColor: StitchTheme.textMuted,
          tabs: const [
            Tab(text: 'UPCOMING'),
            Tab(text: 'ONGOING'),
            Tab(text: 'COMPLETED'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMatches,
        color: StitchTheme.primary,
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
            Icon(Icons.sports_esports_outlined, size: 64, color: StitchTheme.surfaceHighlight),
            const SizedBox(height: 16),
            Text('No $status matches found.', style: const TextStyle(color: StitchTheme.textMuted)),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: scrollController,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final team = matches[index];
          final t = team['tournaments'];
          final isOngoing = status == 'ongoing';
          final isCompleted = status == 'completed';
          
          return _MatchCard(
            team: team,
            tournament: t,
            isOngoing: isOngoing,
            isCompleted: isCompleted,
            status: status,
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> team;
  final Map<String, dynamic> tournament;
  final bool isOngoing;
  final bool isCompleted;
  final String status;

  const _MatchCard({
    required this.team,
    required this.tournament,
    required this.isOngoing,
    required this.isCompleted,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final g = tournament['games'];
    final double progress = (tournament['joined_slots'] ?? 0) / (tournament['total_slots'] ?? 1);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F222A), // Dark premium card background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Image Banner
          Stack(
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: g['banner_url'] != null
                    ? Image.network(g['banner_url'], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: StitchTheme.surfaceHighlight))
                    : Container(color: StitchTheme.surfaceHighlight),
              ),
              // Fade gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1F222A), Colors.transparent, const Color(0xFF1F222A)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Top Right Badge
              Positioned(
                top: 16,
                right: 16,
                child: StitchBadge(
                  text: status.toUpperCase(),
                  color: _getStatusColor(status),
                ),
              ),
              // Left Title Header
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g['name'].toUpperCase(),
                      style: const TextStyle(color: StitchTheme.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tournament['title'],
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. Stats Row Container
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2D36),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Entry', '₹${tournament['entry_fee']}'),
                  Container(width: 1, height: 30, color: Colors.white10),
                  _buildStatColumn('Type', tournament['tournament_type'].toString().toUpperCase()),
                  Container(width: 1, height: 30, color: Colors.white10),
                  _buildStatColumn('Per Kill', '₹${tournament['per_kill_reward']}'),
                ],
              ),
            ),
          ),

          // 3. Status Specific Layouts
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isCompleted && !isOngoing) ...[
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                  ),
                ],
                
                if (isOngoing) ...[
                   Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: StitchTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: StitchTheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ROOM DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: StitchTheme.primary, letterSpacing: 1)),
                            Text('● Live Now', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _roomRow('Room ID:', tournament['room_id'] ?? 'Not Ready'),
                        const SizedBox(height: 8),
                        _roomRow('Password:', tournament['room_password'] ?? 'Not Ready'),
                      ],
                    ),
                  ),
                ],

                if (isCompleted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('My Rank', '#${team['rank'] ?? '-'}', valueColor: StitchTheme.primary),
                        _buildStatColumn('Kills', '${team['kills'] ?? '0'}', valueColor: Colors.white),
                        _buildStatColumn('Winnings', '₹${team['total_prize'] ?? '0'}', valueColor: StitchTheme.success),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StitchButton(
                    text: 'View Match Results', 
                    isSecondary: false, 
                    onPressed: () => context.push('/match-results/${tournament['id']}'),
                  ),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, {Color valueColor = Colors.white}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
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
            child: const Icon(Icons.copy, size: 16, color: StitchTheme.primary),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return StitchTheme.secondary;
      case 'ongoing': return StitchTheme.primary;
      case 'completed': return StitchTheme.success;
      default: return StitchTheme.primary;
    }
  }
}
