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
        title: const Text('My Matches'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StitchTheme.primary,
          labelColor: StitchTheme.primary,
          unselectedLabelColor: StitchTheme.textMuted,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MatchList(matches: upcoming, status: 'upcoming'),
          _MatchList(matches: ongoing, status: 'ongoing'),
          _MatchList(matches: completed, status: 'completed'),
        ],
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final team = matches[index];
        final t = team['tournaments'];
        final g = t['games'];
        final isOngoing = status == 'ongoing';
        final isCompleted = status == 'completed';
        
        return StitchCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                        Text(g['name'], style: const TextStyle(color: StitchTheme.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  StitchBadge(
                    text: status,
                    color: _getStatusColor(status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _infoItem(Icons.access_time, t['start_time'] != null ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(t['start_time']).toLocal()) : 'TBD'),
                  const SizedBox(width: 16),
                  _infoItem(Icons.currency_rupee, 'Entry: ₹${t['entry_fee']}'),
                ],
              ),
              if (isOngoing) ...[
                const SizedBox(height: 16),
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
                      const Text('ROOM DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StitchTheme.primary, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _roomRow('Room ID:', t['room_id'] ?? 'Not Ready'),
                      const SizedBox(height: 4),
                      _roomRow('Password:', t['room_password'] ?? 'Not Ready'),
                    ],
                  ),
                ),
              ],
              if (isCompleted) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: StitchTheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem('Rank', '${team['rank'] ?? '-'}', StitchTheme.primary),
                      _statItem('Kills', '${team['kills'] ?? '0'}', StitchTheme.textMain),
                      _statItem('Prize', '₹${team['total_prize'] ?? '0'}', StitchTheme.success),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _infoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: StitchTheme.textMuted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
      ],
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _roomRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: StitchTheme.textMuted)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
        const Spacer(),
        if (value != 'Not Ready')
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
            },
            child: const Icon(Icons.copy, size: 14, color: StitchTheme.primary),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return StitchTheme.secondary;
      case 'ongoing': return StitchTheme.primary;
      case 'completed': return StitchTheme.success;
      default: return StitchTheme.textMuted;
    }
  }
}
