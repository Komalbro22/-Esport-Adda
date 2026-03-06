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
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StitchCard(
                      padding: EdgeInsets.zero,
                      onTap: () => context.push('/tournament_detail/${t['id']}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: t['banner_url'] != null && t['banner_url'].toString().isNotEmpty
                                    ? Image.network(
                                        t['banner_url'], 
                                        fit: BoxFit.cover, 
                                        errorBuilder: (c,e,s) => Container(color: StitchTheme.surfaceHighlight)
                                      )
                                    : Container(
                                        color: StitchTheme.surfaceHighlight, 
                                        child: const Icon(Icons.sports_esports, size: 40, color: StitchTheme.textMuted)
                                      ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.6),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Row(
                                  children: [
                                    _MiniBadge(text: t['tournament_type'].toString().toUpperCase()),
                                    const SizedBox(width: 8),
                                    _StatusBadge(status: widget.status),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 16,
                                right: 16,
                                child: Text(
                                  t['title'], 
                                  style: const TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.w900, 
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                                  ), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _StatProp('ENTRY FEE', '₹${t['entry_fee']}'),
                                    _StatProp('PER KILL', '₹${t['per_kill_reward']}'),
                                    _StatProp('FILLED', '${t['joined_slots']}/${t['total_slots']}'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SlotProgressBar(
                                  joined: t['joined_slots'] ?? 0, 
                                  total: t['total_slots'] ?? 0
                                ),
                              ],
                            ),
                          )
                        ],
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
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: StitchTheme.textMain, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  const _MiniBadge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: StitchTheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StitchTheme.primary.withOpacity(0.5)),
      ),
      child: Text(text, style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color = StitchTheme.textMuted;
    if (status == 'upcoming') color = StitchTheme.accent;
    if (status == 'ongoing') color = StitchTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }
}
