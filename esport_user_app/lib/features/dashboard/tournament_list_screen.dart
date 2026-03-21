import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../challenges/challenge_list_view.dart';

class TournamentListScreen extends StatefulWidget {
  final String gameId;
  final String gameName;
  final int initialTabIndex;

  const TournamentListScreen({
    Key? key, 
    required this.gameId, 
    required this.gameName,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  late Future<Map<String, dynamic>> _dataCheckFuture;

  @override
  void initState() {
    super.initState();
    _dataCheckFuture = _checkGameData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _checkGameData() async {
    try {
      final gameRes = await Supabase.instance.client
          .from('games')
          .select('challenge_enabled')
          .eq('id', widget.gameId)
          .single();

      final tCountRes = await Supabase.instance.client
          .from('tournaments')
          .select('id')
          .eq('game_id', widget.gameId)
          .limit(1);
      
      final int count = (tCountRes as List).length;
      
      return {
        'challenge_enabled': gameRes['challenge_enabled'] == true,
        'tournament_count': count,
      };
    } catch (e) {
      debugPrint('Tournament list data check failed: $e');
      return {'challenge_enabled': false, 'tournament_count': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataCheckFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF13151D),
            body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }

        final bool challengeEnabled = snapshot.data!['challenge_enabled'] ?? false;
        final int tournamentCount = snapshot.data!['tournament_count'] ?? 0;
        
        // Scenario 1: Challenge Only (On AND No Tournaments)
        if (challengeEnabled && tournamentCount == 0) {
          return _buildChallengeOnlyScreen();
        }

        // Scenario 2: Tournament Only or Mixed
        final tabs = <Tab>[
          const Tab(text: 'Upcoming'),
          const Tab(text: 'Ongoing'),
          const Tab(text: 'Completed'),
        ];
        
        final children = <Widget>[
          _TournamentListView(gameId: widget.gameId, status: 'upcoming', gameName: widget.gameName),
          _TournamentListView(gameId: widget.gameId, status: 'ongoing', gameName: widget.gameName),
          _TournamentListView(gameId: widget.gameId, status: 'completed', gameName: widget.gameName),
        ];

        if (challengeEnabled) {
          tabs.add(const Tab(text: 'Challenges'));
          children.add(ChallengeListView(gameId: widget.gameId, gameName: widget.gameName, showAppBar: false));
        }

        final targetLength = tabs.length;
        
        if (_tabController == null || _tabController!.length != targetLength) {
          int index = widget.initialTabIndex;
          if (index >= targetLength) index = 0;
          _tabController = TabController(length: targetLength, vsync: this, initialIndex: index);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.gameName, style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => context.pop(),
            ),
            bottom: TabBar(
              controller: _tabController!,
              indicatorColor: Colors.blueAccent,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.white60,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              isScrollable: targetLength > 3,
              tabs: tabs,
            ),
          ),
          backgroundColor: const Color(0xFF13151D),
          body: TabBarView(
            controller: _tabController!,
            children: children,
          ),
        );
      },
    );
  }

  Widget _buildChallengeOnlyScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameName, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      backgroundColor: const Color(0xFF13151D),
      body: ChallengeListView(gameId: widget.gameId, gameName: widget.gameName, showAppBar: false),
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
  bool _isLoadMoreRunning = false;
  bool _hasNextPage = true;
  int _page = 0;
  final int _pageSize = 15;
  List<Map<String, dynamic>> _tournaments = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _fetchTournaments();
    _scrollController.addListener(_loadMore);
  }

  void _loadFromCache() {
    final cacheKey = 'tournaments_${widget.gameId}_${widget.status}';
    final cachedData = CacheService.get<List<Map<String, dynamic>>>(cacheKey);
    if (cachedData != null && cachedData.isNotEmpty) {
      _tournaments = cachedData;
      _isLoading = false;
    }
  }

  void _loadMore() async {
    if (_hasNextPage && !_isLoading && !_isLoadMoreRunning && _scrollController.position.extentAfter < 300) {
      if (mounted) setState(() => _isLoadMoreRunning = true);
      _page++;
      await _fetchTournaments(isLoadMore: true);
      if (mounted) setState(() => _isLoadMoreRunning = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTournaments({bool isLoadMore = false}) async {
    try {
      if (!isLoadMore) {
        setState(() {
          _isLoading = true;
          _page = 0;
          _hasNextPage = true;
        });
      }

      final from = _page * _pageSize;
      final to = from + _pageSize - 1;
      final user = _supabase.auth.currentUser;
      
      var query = _supabase.from('tournaments')
          .select('id, title, entry_fee, total_prize_pool, joined_slots, total_slots, status, start_time, banner_url, tournament_type, per_kill_reward, game_id, prize_type, commission_percentage, rank_percentages, games(name)')
          .eq('game_id', widget.gameId)
          .eq('status', widget.status)
          .order('start_time', ascending: widget.status == 'upcoming')
          .range(from, to);

      if (widget.status == 'completed' && user != null) {
        query = _supabase.from('tournaments')
            .select('id, title, entry_fee, total_prize_pool, joined_slots, total_slots, status, start_time, banner_url, tournament_type, per_kill_reward, game_id, prize_type, commission_percentage, rank_percentages, joined_teams(user_id, rank, kills, total_prize)')
            .eq('game_id', widget.gameId)
            .eq('status', widget.status)
            .order('start_time', ascending: false)
            .range(from, to);
      }
            
      final data = await query;
      final List<Map<String, dynamic>> fetchedTournaments = List<Map<String, dynamic>>.from(data as List);

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _tournaments.addAll(fetchedTournaments);
          } else {
            _tournaments = fetchedTournaments;
          }
          
          if (widget.status == 'completed' && user != null) {
             _tournaments = _tournaments.map((t) {
              final joinedTeams = t['joined_teams'] as List?;
              final myTeam = joinedTeams?.where((team) => team['user_id'] == user.id).toList();
              t['my_result'] = myTeam != null && myTeam.isNotEmpty ? myTeam.first : null;
              return t;
            }).toList();
          }

          // Cache first page
          if (!isLoadMore) {
            final cacheKey = 'tournaments_${widget.gameId}_${widget.status}';
            CacheService.set(cacheKey, _tournaments, duration: const Duration(minutes: 2));
          }

          _hasNextPage = fetchedTournaments.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _isLoadMoreRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => const TournamentShimmer(),
      );
    }
    
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
                    child: _TournamentCard(
                      tournament: t, 
                      gameName: widget.gameName,
                      status: widget.status,
                      isOngoing: isOngoing,
                    ),
                  );
                },
                childCount: _tournaments.length,
              ),
            ),
          ),
          if (_isLoadMoreRunning)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: StitchTheme.primary)),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildInfoItem(IconData icon, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: Colors.white60),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final String gameName;
  final String status;
  final bool isOngoing;

  const _TournamentCard({
    required this.tournament,
    required this.gameName,
    required this.status,
    required this.isOngoing,
  });

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    
    // Prize Calculation Logic
    double displayPrize = (t['total_prize_pool'] ?? 0).toDouble();
    bool isDynamic = t['prize_type'] == 'dynamic';
    if (isDynamic) {
      displayPrize = TournamentPrizeService.calculateCurrentPool(
        entryFee: (t['entry_fee'] ?? 0).toDouble(),
        joinedPlayers: t['joined_slots'] ?? 0,
        commissionPercentage: (t['commission_percentage'] ?? 0).toDouble(),
      );
    }

    return GestureDetector(
      onTap: () => context.push('/tournament_detail/${t['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F222A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: t['banner_url'] != null && t['banner_url'].toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: t['banner_url'], 
                          fit: BoxFit.cover, 
                          placeholder: (context, url) => const StitchShimmer(),
                          errorWidget: (c,e,s) => Container(color: const Color(0xFF2A2D36))
                        )
                      : Container(
                          color: const Color(0xFF2A2D36), 
                          child: const Icon(Icons.sports_esports, size: 40, color: Colors.white30)
                        ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t['tournament_type'].toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ),
                if (isDynamic)
                  Positioned(
                    top: 12,
                    left: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'DYNAMIC',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
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
                          gameName.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          t['title'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isOngoing)
                        const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.redAccent, size: 8),
                            SizedBox(width: 4),
                            Text('LIVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        )
                      else if (t['start_time'] != null)
                        TournamentCountdown(
                          startTime: DateTime.parse(t['start_time']),
                          isCompact: true,
                          status: status,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubInfoItem(Icons.payments_rounded, 'Entry Fee', '₹${t['entry_fee']}'),
                  _buildSubInfoItem(Icons.emoji_events_rounded, 'Prize Pool', '₹${displayPrize.toInt()}', color: Colors.greenAccent),
                  _buildSubInfoItem(Icons.sports_esports_rounded, 'Mode', t['tournament_type'].toString().toUpperCase()),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.white10),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SlotProgressBar(
                joined: t['joined_slots'] ?? 0,
                total: t['total_slots'] ?? 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubInfoItem(IconData icon, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: Colors.white60),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
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
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                    ? CachedNetworkImage(
                        imageUrl: t['banner_url'], 
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const StitchShimmer(),
                        errorWidget: (c,e,s) => Container(color: const Color(0xFF2A2D36)),
                      )
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
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
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
                            color: Colors.green.withOpacity(0.1),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
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

