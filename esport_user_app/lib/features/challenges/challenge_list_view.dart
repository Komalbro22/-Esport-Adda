import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'create_challenge_dialog.dart';
import 'challenge_detail_screen.dart';
import 'reputation_badge_widget.dart';

class ChallengeListView extends StatefulWidget {
  final String gameId;
  final String gameName;
  final bool showAppBar;

  const ChallengeListView({
    Key? key, 
    required this.gameId, 
    required this.gameName,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<ChallengeListView> createState() => _ChallengeListViewState();
}

class _ChallengeListViewState extends State<ChallengeListView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _challenges = [];
  String _currentFilter = 'open';
  int _activeCount = 0;
  int _userFairScore = 100;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([
      _fetchChallenges(),
      _fetchStats(),
    ]);
  }

  Future<void> _fetchStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Active Challenges Count
      final countRes = await _supabase.from('challenges')
          .select('*')
          .eq('game_id', widget.gameId)
          .eq('status', 'open');
      
      final activeCount = (countRes as List).length;
      
      // User Fair Score
      final userRes = await _supabase.from('users').select('fair_score').eq('id', user.id).single();

      if (mounted) {
        setState(() {
          _activeCount = activeCount;
          _userFairScore = userRes['fair_score'] ?? 100;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  Future<void> _fetchChallenges() async {
    try {
      setState(() => _isLoading = true);
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Handle block list
      List<String> blockedIds = [];
      try {
        final List blocks = await _supabase.from('blocked_users').select('blocked_user_id').eq('user_id', user.id);
        blockedIds = blocks.map((b) => b['blocked_user_id'].toString()).toList();
      } catch (e) {
        debugPrint('Error fetching block list: $e');
      }

      // Build query with alias joins to disambiguate multiple foreign keys to 'users'
      // Note: No spaces in select string to avoid potential PostgREST parsing issues
      // Build query with safe join syntax to fix NoSuchMethodError
      // and avoid previous 400 Bad Request error.
      const selectStr = '*,creator:users!creator_id(username),opponent:users!opponent_id(username),games(name,logo_url)';
      
      var query = _supabase.from('challenges').select(selectStr).eq('game_id', widget.gameId);

      if (_currentFilter == 'open') {
        query = query.eq('status', 'open');
        if (blockedIds.isNotEmpty) {
          query = query.not('creator_id', 'in', blockedIds);
        }
      } else if (_currentFilter == 'my') {
        query = query.or('creator_id.eq.${user.id},opponent_id.eq.${user.id}');
        
        switch (_mySubFilter) {
          case 'open':
            query = query.eq('status', 'open');
            break;
          case 'ongoing':
            query = query.inFilter('status', ['accepted', 'ready', 'ongoing']);
            break;
          case 'completed':
            query = query.eq('status', 'completed');
            break;
          case 'dispute':
            query = query.eq('status', 'dispute');
            break;
        }
      }

      final data = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _challenges = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching challenges: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _challenges = []; // Reset to empty on error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F111A),
        appBar: widget.showAppBar ? _buildAppBar() : null,
        body: Column(
          children: [
            TabBar(
              onTap: (index) {
                setState(() => _currentFilter = index == 0 ? 'open' : 'my');
                _fetchChallenges();
              },
              indicatorColor: Colors.deepPurpleAccent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(text: 'Open Challenges'),
                Tab(text: 'My Challenges'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildChallengesList(),
                  _buildMyChallengesSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesList() {
    return RefreshIndicator(
      onRefresh: _fetchInitialData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderContent()),
          SliverToBoxAdapter(child: _buildFilterSection('Active Challenges')),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)))
          else if (_challenges.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildChallengeCard(_challenges[index]),
                  childCount: _challenges.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _mySubFilter = 'open';

  Widget _buildMyChallengesSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSubFilterChip('Open', 'open'),
              _buildSubFilterChip('Ongoing', 'ongoing'),
              _buildSubFilterChip('Completed', 'completed'),
              _buildSubFilterChip('Dispute', 'dispute'),
            ],
          ),
        ),
        Expanded(child: _buildChallengesList()),
      ],
    );
  }

  Widget _buildSubFilterChip(String label, String value) {
    final isSelected = _mySubFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mySubFilter = value;
          // You might need to refine _fetchChallenges to use _mySubFilter when _currentFilter == 'my'
        });
        _fetchChallenges();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurpleAccent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.deepPurpleAccent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.deepPurpleAccent : Colors.white60,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded, size: 18, color: Colors.deepPurpleAccent),
            label: const Text('Filter', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> c) {
    final user = _supabase.auth.currentUser;
    final isCreator = c['creator_id'] == user?.id;
    final isParticipant = isCreator || c['opponent_id'] == user?.id;
    final status = c['status'] as String;

    // Handle DIFFERENT UI based on status for "My Challenges"
    if (_currentFilter == 'my') {
      if (_mySubFilter == 'ongoing') return _buildOngoingCard(c);
      if (_mySubFilter == 'completed' || _mySubFilter == 'dispute') return _buildCompletedCard(c);
      return _buildOpenMyChallengeCard(c);
    }

    return GestureDetector(
      onTap: isParticipant 
        ? () => context.push('/challenge_detail/${c['id']}')
        : () async {
            await context.push('/accept_challenge/${c['id']}');
            _fetchInitialData();
          },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(c['creator']['username'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          const SizedBox(width: 8),
                          ReputationBadge(score: c['creator']['fair_score'] ?? 100, fontSize: 9),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 12, color: Colors.greenAccent),
                          const SizedBox(width: 4),
                          Text('Fair Score: ${c['creator']['fair_score']}+', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Entry Fee', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('₹${c['entry_fee']}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 20)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildTag(Icons.groups_rounded, 'Mode: ${c['mode']}', iconWidget: c['games']?['logo_url'] != null ? ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: c['games']?['logo_url'], width: 14, height: 14, fit: BoxFit.cover)) : null),
                const SizedBox(width: 12),
                _buildTag(Icons.gavel_rounded, c['rules']?.toString().isNotEmpty == true ? c['rules'] : 'Standard Rules'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isParticipant 
                  ? () => context.push('/challenge_detail/${c['id']}')
                  : () async {
                      await context.push('/accept_challenge/${c['id']}');
                      _fetchInitialData();
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isParticipant ? Colors.blueGrey.withOpacity(0.2) : Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  isParticipant ? 'VIEW DETAILS' : 'Accept Challenge',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3), width: 2),
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white.withOpacity(0.05),
          child: const Icon(Icons.person_outline_rounded, color: Colors.deepPurpleAccent),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, {Widget? iconWidget}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget ?? Icon(icon, size: 14, color: Colors.deepPurpleAccent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_esports_outlined, size: 64, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text('No challenges found', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Text(
        '${widget.gameName} Challenges',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white54, size: 22),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildHeaderContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurpleAccent.withOpacity(0.15), Colors.blueAccent.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStatBox('ACTIVE NOW', '$_activeCount Players', Icons.bolt_rounded, Colors.amber),
                    const SizedBox(width: 16),
                    _buildStatBox('YOUR FAIR SCORE', '$_userFairScore/100', Icons.shield_rounded, Colors.greenAccent),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _showCreateChallengeDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: Colors.deepPurpleAccent.withOpacity(0.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 22),
                        SizedBox(width: 12),
                        Text('CREATE NEW CHALLENGE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }


  Widget _buildOngoingCard(Map<String, dynamic> c) {
    final opponent = c['creator_id'] == _supabase.auth.currentUser?.id ? c['opponent'] : c['creator'];
    final double prizePool = c['entry_fee'] * 2 * (1 - ((c['commission_percent'] ?? 10) / 100));
    final String? gameImageUrl = c['games']?['image_url'];

    return GestureDetector(
      onTap: () => context.push('/challenge_detail/${c['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D).withOpacity(0.8),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                image: gameImageUrl != null ? DecorationImage(
                  image: CachedNetworkImageProvider(gameImageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
                ) : null,
                color: Colors.deepPurpleAccent.withOpacity(0.1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white12,
                      child: Icon(Icons.person, color: Colors.white70, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vs ${opponent != null ? opponent['username'] : 'Opponent'}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${c['games']?['name'] ?? widget.gameName} ${c['mode']}',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.4))),
                      child: const Text('LIVE', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildCredentialBox('ROOM CREDENTIALS', 'ID: ${c['room_id'] ?? 'WAITING'}', 'Pass: ${c['room_pass'] ?? '****'}'),
                      const SizedBox(width: 12),
                      _buildCredentialBox('ENTRY DETAILS', 'Fee: ₹${c['entry_fee']}', 'Prize: ₹${prizePool.toStringAsFixed(0)}', color: Colors.deepPurpleAccent),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.deepPurpleAccent),
                          SizedBox(width: 8),
                          Text('IN PROGRESS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/challenge_detail/${c['id']}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Submit Result', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> c) {
    final bool isWinner = c['winner_id'] == _supabase.auth.currentUser?.id;
    final winnerName = isWinner ? 'You (Victory!)' : (c['winner_id'] != null ? 'Opponent' : 'Draw/Refunded');
    final String? gameImageUrl = c['games']?['image_url'];

    return GestureDetector(
      onTap: () => context.push('/challenge_detail/${c['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                image: gameImageUrl != null ? DecorationImage(
                  image: CachedNetworkImageProvider(gameImageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
                ) : null,
                color: Colors.deepPurpleAccent.withOpacity(0.1),
              ),
              child: gameImageUrl == null ? const Center(child: Icon(Icons.sports_esports_rounded, color: Colors.white10, size: 48)) : null,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Vs ${c['creator_id'] == _supabase.auth.currentUser?.id ? (c['opponent']?['username'] ?? 'Opponent') : (c['creator']?['username'] ?? 'Creator')}', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('₹${(c['entry_fee'] * 2 * 0.9).toStringAsFixed(0)}', 
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            c['status'] == 'dispute' ? Icons.gavel_rounded : Icons.emoji_events_rounded, 
                            color: c['status'] == 'dispute' ? Colors.orangeAccent : (isWinner ? Colors.greenAccent : Colors.white24), 
                            size: 24
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['status'] == 'dispute' ? 'STATUS' : 'WINNER', style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text(
                                c['status'] == 'dispute' ? 'IN DISPUTE' : winnerName, 
                                style: TextStyle(
                                  color: c['status'] == 'dispute' ? Colors.orangeAccent : (isWinner ? Colors.greenAccent : Colors.white70), 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14
                                )
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/challenge_detail/${c['id']}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('View Details', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenMyChallengeCard(Map<String, dynamic> c) {
    final String? gameImageUrl = c['games']?['logo_url'];
    return GestureDetector(
      onTap: () => context.push('/challenge_detail/${c['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                image: gameImageUrl != null ? DecorationImage(
                  image: CachedNetworkImageProvider(gameImageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
                ) : null,
                color: Colors.blueGrey.withOpacity(0.1),
              ),
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('PUBLIC LOBBY', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['mode'] ?? '1v1 Battle', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          const Text('Searching for opponent...', style: TextStyle(color: Colors.white24, fontSize: 11)),
                        ],
                      ),
                      Text('₹${(c['entry_fee'] * 2 * 0.9).toStringAsFixed(0)}', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildTag(Icons.attach_money_rounded, 'Fee: ₹${c['entry_fee']}'),
                      const SizedBox(width: 12),
                      _buildTag(Icons.sports_esports_rounded, c['mode']),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelChallenge(c['id']),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/challenge_detail/${c['id']}'),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.withOpacity(0.1),
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialBox(String title, String line1, String line2, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Text(line1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(line2, style: TextStyle(color: color ?? Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelChallenge(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text('Cancel Challenge?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure? Entry fee will be refunded to your wallet.', style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('YES, CANCEL', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      StitchSnackbar.showLoading(context, 'Cancelling...');
      await _supabase.from('challenges').update({'status': 'cancelled'}).eq('id', id);
      StitchSnackbar.showSuccess(context, 'Challenge cancelled');
      _fetchInitialData();
    } catch (e) {
      StitchSnackbar.showError(context, 'Failed to cancel');
    }
  }

  void _showCreateChallengeDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateChallengeDialog(gameId: widget.gameId, gameName: widget.gameName),
    );
    if (result == true) _fetchInitialData();
  }
}
