import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({Key? key, required this.tournamentId}) : super(key: key);

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _tournament;
  Map<String, dynamic>? _wallet;
  bool _isLoading = true;
  bool _isJoining = false;
  bool _hasJoined = false;
  Map<String, dynamic>? _joinedTeamData;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final futures = await Future.wait([
        _supabase.from('tournaments').select('*, games(name)').eq('id', widget.tournamentId).single(),
        _supabase.from('joined_teams').select('*').eq('tournament_id', widget.tournamentId).eq('user_id', user.id).maybeSingle(),
        _supabase.from('user_wallets').select('*').eq('user_id', user.id).single(),
      ]);

      if (mounted) {
        setState(() {
          _tournament = futures[0] as Map<String, dynamic>;
          _joinedTeamData = futures[1] as Map<String, dynamic>?;
          _wallet = futures[2] as Map<String, dynamic>;
          _hasJoined = _joinedTeamData != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load details');
      }
    }
  }

  Future<void> _navigateToJoin() async {
    final entryFee = (_tournament!['entry_fee'] ?? 0).toDouble();
    final deposit = (_wallet!['deposit_wallet'] ?? 0).toDouble();
    final winning = (_wallet!['winning_wallet'] ?? 0).toDouble();
    final totalBalance = deposit + winning;

    if (totalBalance < entryFee) {
      _showInsufficientBalanceDialog();
      return;
    }

    final success = await context.push<bool?>('/join_tournament_form/${widget.tournamentId}');
    if (success == true) {
      _fetchDetails();
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F222A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Insufficient Balance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Your total balance (₹${(_wallet!['deposit_wallet'] + _wallet!['winning_wallet']).toStringAsFixed(2)}) is less than the entry fee (₹${_tournament!['entry_fee']}). Please add money to continue.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/deposit');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Money', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());
    if (_tournament == null) return Scaffold(appBar: AppBar(), body: const StitchError(message: 'Not found'));

    final t = _tournament!;
    final status = t['status'];

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF13151D),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: const Color(0xFF13151D),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (t['banner_url'] != null && t['banner_url'].toString().isNotEmpty)
                        CachedNetworkImage(imageUrl: t['banner_url'], fit: BoxFit.cover)
                      else
                        Container(color: const Color(0xFF2A2D36), child: const Icon(Icons.sports_esports, color: Colors.white24, size: 48)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                              const Color(0xFF13151D),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 60,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(6)),
                              child: Text(t['games']?['name']?.toString().toUpperCase() ?? 'GAME', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                            const SizedBox(height: 8),
                            Text(t['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151D),
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: const TabBar(
                      isScrollable: false,
                      indicatorColor: Colors.blueAccent,
                      indicatorWeight: 3,
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: Colors.white38,
                      labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      tabs: [
                        Tab(text: 'OVERVIEW'),
                        Tab(text: 'PRIZES'),
                        Tab(text: 'PLAYERS'),
                        Tab(text: 'RULES'),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _OverviewTab(tournament: t, hasJoined: _hasJoined, joinedTeamData: _joinedTeamData),
              _PrizesTab(tournament: t),
              _ParticipantsTab(tournamentId: widget.tournamentId),
              _RulesTab(rules: t['rules'] ?? 'No special rules shared.'),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _buildActionBtn(),
        bottomNavigationBar: const SizedBox(height: 80),
      ),
    );
  }

  Widget? _buildActionBtn() {
    final status = _tournament!['status'];
    final isFull = _tournament!['joined_slots'] >= _tournament!['total_slots'];

    if (_hasJoined) {
      if (status == 'upcoming') {
        return _actionButton(text: 'JOINED SUCCESSFULLY', color: Colors.green, icon: Icons.check_circle_rounded);
      }
      if (status == 'ongoing') {
        return _actionButton(text: 'JOIN MATCH', color: Colors.blueAccent, icon: Icons.gamepad_rounded, onTap: () {
          StitchSnackbar.showSuccess(context, 'Launching Match...');
        });
      }
      return null;
    }

    if (status == 'upcoming') {
      if (isFull) {
        return _actionButton(text: 'TOURNAMENT FULL', color: const Color(0xFF2A2D36), textColor: Colors.white54);
      }
      
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: _isJoining ? null : _navigateToJoin,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: StitchTheme.primaryGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: _isJoining 
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : Row(
                  children: [
                    const Expanded(child: Center(child: Text('Join Tournament', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)))),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(24)),
                      child: Text('₹${_tournament!['entry_fee']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
          ),
        ),
      );
    }
    return null;
  }

  Widget _actionButton({required String text, required Color color, Color textColor = Colors.white, IconData? icon, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 16)),
              if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: textColor, size: 20)],
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final bool hasJoined;
  final Map<String, dynamic>? joinedTeamData;

  const _OverviewTab({required this.tournament, required this.hasJoined, this.joinedTeamData});

  @override
  Widget build(BuildContext context) {
    final status = tournament['status'];
    final t = tournament;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Grid
          Row(
            children: [
              Expanded(child: _InfoCard(icon: Icons.payments_rounded, label: 'ENTRY FEE', value: '₹${t['entry_fee']}')),
              const SizedBox(width: 12),
              Expanded(child: _InfoCard(icon: Icons.radar_rounded, label: 'PER KILL', value: '₹${t['per_kill_reward']}')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _InfoCard(icon: Icons.groups_rounded, label: 'TYPE', value: t['tournament_type'].toString().toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: _InfoCard(icon: Icons.map_rounded, label: 'MAP', value: t['map_name']?.toString().toUpperCase() ?? 'RANDOM')),
            ],
          ),
          const SizedBox(height: 32),
          
          // Countdown
          if (status == 'upcoming' && t['start_time'] != null) ...[
             const _SectionTitle(title: 'STARTS IN'),
             const SizedBox(height: 16),
             TournamentCountdown(startTime: DateTime.parse(t['start_time']), status: status),
             const SizedBox(height: 32),
          ],

          // Slots
          const _SectionTitle(title: 'SLOT FILLING STATUS'),
          const SizedBox(height: 16),
          SlotProgressBar(joined: t['joined_slots'] ?? 0, total: t['total_slots'] ?? 1),
          const SizedBox(height: 32),

          // Room Details (If joined)
          if (hasJoined && (status == 'ongoing' || (status == 'upcoming' && t['room_id'] != null))) ...[
            const _SectionTitle(title: 'ROOM CREDENTIALS'),
            const SizedBox(height: 16),
            _RoomDetailsCard(roomId: t['room_id'], password: t['room_password']),
            const SizedBox(height: 32),
          ],

          // Post Match Result
          if (status == 'completed' && hasJoined && joinedTeamData != null) ...[
            const _SectionTitle(title: 'YOUR PERFORMANCE'),
            const SizedBox(height: 16),
            _ResultCard(data: joinedTeamData!),
            const SizedBox(height: 32),
          ],
          
          const _SectionTitle(title: 'ABOUT TOURNAMENT'),
          const SizedBox(height: 12),
          Text(t['prize_description'] ?? 'No detailed description available.', style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.6)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _PrizesTab extends StatelessWidget {
  final Map<String, dynamic> tournament;
  const _PrizesTab({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final bool isDynamic = t['prize_type'] == 'dynamic';
    double currentPool = (t['total_prize_pool'] ?? 0).toDouble();
    double maxPool = currentPool;

    if (isDynamic) {
      currentPool = TournamentPrizeService.calculateCurrentPool(
        entryFee: (t['entry_fee'] ?? 0).toDouble(),
        joinedPlayers: t['joined_slots'] ?? 0,
        commissionPercentage: (t['commission_percentage'] ?? 0).toDouble(),
      );
      maxPool = TournamentPrizeService.calculateMaxPool(
        entryFee: (t['entry_fee'] ?? 0).toDouble(),
        totalSlots: t['total_slots'] ?? 1,
        commissionPercentage: (t['commission_percentage'] ?? 0).toDouble(),
      );
    }

    final rankData = isDynamic 
        ? TournamentPrizeService.calculateRankRewards(currentPool: currentPool, rankPercentages: t['rank_percentages'] ?? {})
        : (t['rank_prizes'] as Map<String, dynamic>? ?? {});

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Pool Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF1E3A8A).withOpacity(0.6), const Color(0xFF1E1B4B)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 48),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isDynamic ? 'CURRENT PRIZE POOL' : 'TOTAL PRIZE POOL', style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text('₹${currentPool.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      if (isDynamic) ...[
                        const SizedBox(height: 8),
                        Text('MAX PRIZE POOL: ₹${maxPool.toInt()}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const _SectionTitle(title: 'RANK WISE REWARDS'),
          const SizedBox(height: 16),
          if (rankData.isEmpty)
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 40),
               child: Center(child: Text('Prize distribution details coming soon.', style: TextStyle(color: Colors.white38))),
             )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rankData.length,
              itemBuilder: (context, index) {
                final entry = rankData.entries.elementAt(index);
                final rank = entry.key;
                final prize = entry.value;
                return _PrizeTile(rank: rank, amount: prize.toDouble());
              },
            ),
          if (isDynamic) ...[
             const SizedBox(height: 24),
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
               child: const Row(
                 children: [
                   Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 20),
                   const SizedBox(width: 12),
                   Expanded(child: Text('This is a dynamic prize pool. Rewards increase as more players join.', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w500))),
                 ],
               ),
             ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _ParticipantsTab extends StatefulWidget {
  final String tournamentId;

  const _ParticipantsTab({required this.tournamentId});

  @override
  State<_ParticipantsTab> createState() => _ParticipantsTabState();
}

class _ParticipantsTabState extends State<_ParticipantsTab> {
  final _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  bool _isLoadMoreRunning = false;
  int _page = 0;
  final int _pageSize = 50;
  bool _hasNextPage = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
    _scrollController.addListener(_loadMore);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchParticipants({bool isLoadMore = false}) async {
    try {
      final query = _supabase
          .from('joined_teams')
          .select('team_data, users(id, name, username, avatar_url)')
          .eq('tournament_id', widget.tournamentId)
          .order('created_at', ascending: true)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      final data = await query;
      final List<Map<String, dynamic>> fetchedData = List<Map<String, dynamic>>.from(data as List);

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _participants.addAll(fetchedData);
          } else {
            _participants.clear();
            _participants.addAll(fetchedData);
          }
          _isLoading = false;
          _hasNextPage = fetchedData.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadMore() async {
    if (_hasNextPage && !_isLoading && !_isLoadMoreRunning && _scrollController.position.extentAfter < 300) {
      if (mounted) setState(() => _isLoadMoreRunning = true);
      _page++;
      await _fetchParticipants(isLoadMore: true);
      if (mounted) setState(() => _isLoadMoreRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _participants.isEmpty) {
      return const Center(child: StitchLoading());
    }

    if (_participants.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_rounded, size: 64, color: Colors.white10),
            SizedBox(height: 16),
            Text('No players have joined yet.', style: TextStyle(color: Colors.white38, fontSize: 14)),
            Text('Be the first to join and compete!', style: TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: _participants.length + (_hasNextPage ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _participants.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: StitchLoading(),
            ),
          );
        }

        final user = _participants[index]['users'];
        final List<dynamic>? teamData = _participants[index]['team_data'] as List<dynamic>?;
        
        if (user == null) return const SizedBox.shrink();

        // Find the leader/primary player's gaming info
        String ign = 'N/A';
        String uid = 'N/A';
        if (teamData != null && teamData.isNotEmpty) {
          final leader = teamData.firstWhere((p) => p['is_leader'] == 'true' || p['is_leader'] == true, orElse: () => teamData.first);
          ign = leader['name']?.toString() ?? 'N/A';
          uid = leader['uid']?.toString() ?? 'N/A';
        }
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F222A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              StitchAvatar(radius: 26, name: user['name'] ?? 'P', avatarUrl: user['avatar_url']),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? 'Player', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('@${user['username'] ?? 'user'}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SmallBadge(label: 'IGN', value: ign, color: Colors.cyanAccent),
                        const SizedBox(width: 8),
                        _SmallBadge(label: 'UID', value: uid, color: Colors.purpleAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 20),
            ],
          ),
        );
      },
    );
  }
}

class _RulesTab extends StatelessWidget {
  final String rules;
  const _RulesTab({required this.rules});

  @override
  Widget build(BuildContext context) {
    final rulesList = rules.split('\n').where((r) => r.trim().isNotEmpty).toList();
    if (rulesList.isEmpty) rulesList.add('Standard tournament rules apply.');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'IMPORTANT RULES'),
          const SizedBox(height: 20),
          ...rulesList.map((rule) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.gavel_rounded, color: Colors.blueAccent, size: 14),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(rule.trim(), style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5))),
              ],
            ),
          )),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// Support Widgets

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1F222A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 18),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PrizeTile extends StatelessWidget {
  final String rank;
  final double amount;
  const _PrizeTile({required this.rank, required this.amount});

  @override
  Widget build(BuildContext context) {
    final rankNum = int.tryParse(rank.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF1F222A), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _buildRankBadge(rankNum),
          const SizedBox(width: 16),
          Expanded(child: Text(rankNum == 1 ? 'WINNER' : 'RANK $rankNum', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
          Text('₹${amount.toInt()}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color = Colors.white10;
    if (rank == 1) color = Colors.amber;
    if (rank == 2) color = const Color(0xFFC0C0C0);
    if (rank == 3) color = const Color(0xFFCD7F32);

    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(rank.toString(), style: TextStyle(color: rank <= 3 ? color : Colors.white60, fontWeight: FontWeight.w900, fontSize: 14)),
    );
  }
}

class _RoomDetailsCard extends StatelessWidget {
  final String? roomId;
  final String? password;
  const _RoomDetailsCard({this.roomId, this.password});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.greenAccent.withOpacity(0.2))),
      child: Column(
        children: [
          _CopyRow(label: 'ROOM ID', value: roomId ?? 'PENDING'),
          const Divider(color: Colors.white10, height: 32),
          _CopyRow(label: 'PASSWORD', value: password ?? 'PENDING'),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  const _CopyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        IconButton(icon: const Icon(Icons.content_copy_rounded, color: Colors.greenAccent, size: 20), onPressed: () {}),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.greenAccent.withOpacity(0.2), Colors.green.withOpacity(0.05)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'RANK', value: '#${data['rank'] ?? '-'}'),
          _Stat(label: 'KILLS', value: '${data['kills'] ?? 0}'),
          _Stat(label: 'PRIZE', value: '₹${data['total_prize'] ?? 0}', color: Colors.greenAccent),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2));
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SmallBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: color.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

