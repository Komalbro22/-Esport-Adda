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
          _TournamentListView(gameId: widget.gameId, status: 'upcoming'),
          _TournamentListView(gameId: widget.gameId, status: 'ongoing'),
          _TournamentListView(gameId: widget.gameId, status: 'completed'),
        ],
      ),
    );
  }
}

class _TournamentListView extends StatefulWidget {
  final String gameId;
  final String status;

  const _TournamentListView({Key? key, required this.gameId, required this.status}) : super(key: key);

  @override
  State<_TournamentListView> createState() => _TournamentListViewState();
}

class _TournamentListViewState extends State<_TournamentListView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tournaments = [];

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    try {
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
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: StitchLoading());
    if (_tournaments.isEmpty) {
      return Center(
        child: Text(
          'No ${widget.status} tournaments found.', 
          style: const TextStyle(color: StitchTheme.textMuted)
        )
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTournaments,
      color: StitchTheme.primary,
      backgroundColor: StitchTheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tournaments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final t = _tournaments[index];
          final bool isFull = t['joined_slots'] >= t['total_slots'];

          return StitchCard(
            padding: EdgeInsets.zero,
            onTap: () => context.push('/tournament_detail/${t['id']}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    if (t['banner_url'] != null && t['banner_url'].toString().isNotEmpty)
                      SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: Image.network(t['banner_url'], fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(height: 140, color: StitchTheme.surfaceHighlight)),
                      )
                    else
                      Container(height: 140, width: double.infinity, color: StitchTheme.surfaceHighlight, child: const Icon(Icons.sports_esports, size: 40, color: StitchTheme.textMuted)),
                    
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        children: [
                          StitchBadge(
                            text: t['tournament_type'].toString(),
                            color: StitchTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          StitchBadge(
                            text: widget.status,
                            color: widget.status == 'upcoming' ? StitchTheme.accent : (widget.status == 'ongoing' ? StitchTheme.success : StitchTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatProp('Entry Fee', '₹${t['entry_fee']}'),
                          _StatProp('Per Kill', '₹${t['per_kill_reward']}'),
                          _StatProp('Slots', '${t['joined_slots']}/${t['total_slots']}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: t['total_slots'] > 0 ? t['joined_slots'] / t['total_slots'] : 0,
                          backgroundColor: StitchTheme.surfaceHighlight,
                          color: isFull ? StitchTheme.error : StitchTheme.success,
                          minHeight: 6,
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatProp extends StatelessWidget {
  final String label;
  final String value;
  const _StatProp(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: StitchTheme.textMain, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
