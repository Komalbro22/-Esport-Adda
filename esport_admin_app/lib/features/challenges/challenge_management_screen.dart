import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ChallengeManagementScreen extends StatefulWidget {
  const ChallengeManagementScreen({super.key});

  @override
  State<ChallengeManagementScreen> createState() => _ChallengeManagementScreenState();
}

class _ChallengeManagementScreenState extends State<ChallengeManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _games = [];
  
  // Stats
  int _activeCount = 0;
  int _disputeCount = 0;
  double _totalPool = 0;
  int _newPlayersCount = 0;

  // Filters
  String _selectedStatus = 'All Status';
  String _selectedGame = 'All Games';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final results = await Future.wait([
        _supabase.from('games').select('id, name').order('name'),
        _fetchChallenges(),
        _fetchStats(),
      ]);
      
      if (mounted) {
        setState(() {
          _games = List<Map<String, dynamic>>.from(results[0] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<dynamic> _fetchChallenges() async {
    var query = _supabase.from('challenges')
        .select('*, creator:users!creator_id(username, avatar_url), opponent:users!opponent_id(username, avatar_url), games(name)');

    if (_selectedStatus != 'All Status') {
      query = query.eq('status', _selectedStatus.toLowerCase());
    }
    
    if (_selectedGame != 'All Games') {
      final game = _games.firstWhere((g) => g['name'] == _selectedGame);
      query = query.eq('game_id', game['id']);
    }

    final data = await query.order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _challenges = List<Map<String, dynamic>>.from(data as List);
      });
    }
    return data;
  }

  Future<void> _fetchStats() async {
    try {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      
      final challengesRes = await _supabase.from('challenges').select('status, entry_fee');
      final challenges = challengesRes as List;

      // Get new users count
      final newUsersRes = await _supabase.from('users').select('id').gte('created_at', twentyFourHoursAgo);
      final newUsersCount = (newUsersRes as List).length;

      if (mounted) {
        setState(() {
          _activeCount = challenges.where((c) => ['open', 'accepted', 'ready', 'ongoing'].contains(c['status'])).length;
          _disputeCount = challenges.where((c) => c['status'] == 'dispute').length;
          _totalPool = challenges
              .where((c) => ['accepted', 'ready', 'ongoing'].contains(c['status']))
              .fold(0.0, (sum, c) => sum + ((c['entry_fee'] as num?)?.toDouble() ?? 0.0) * 2);
          _newPlayersCount = newUsersCount;
        });
      }
    } catch (e) {
      debugPrint('Challenge management fetch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () {},
            tooltip: 'Export Report',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading 
        ? const Center(child: StitchLoading())
        : RefreshIndicator(
            onRefresh: _fetchInitialData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monitor and moderate ongoing player matches.', style: TextStyle(color: StitchTheme.textMuted)),
                  const SizedBox(height: 32),
                  _buildStatsGrid(),
                  const SizedBox(height: 48),
                  _buildFilters(),
                  const SizedBox(height: 24),
                  _buildChallengeList(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStatsGrid() {
    return StitchGrid(
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard('Active Matches', _activeCount.toString(), Icons.sports_esports, Colors.green),
        _buildStatCard('Open Disputes', _disputeCount.toString(), Icons.report_problem_outlined, Colors.red),
        _buildStatCard('Total Pool (24h)', '₹${_totalPool.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined, Colors.blue),
        _buildStatCard('New Players (24h)', _newPlayersCount.toString(), Icons.people_outline, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return StitchCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }


  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: StitchTheme.surface, borderRadius: BorderRadius.circular(20)),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        alignment: WrapAlignment.start,
        children: [
          _buildFilterDropdown('STATUS', _selectedStatus, ['All Status', 'Open', 'Accepted', 'Ready', 'Ongoing', 'Completed', 'Dispute'], (v) {
            setState(() => _selectedStatus = v!);
            _fetchChallenges();
          }),
          _buildFilterDropdown('GAME', _selectedGame, ['All Games', ..._games.map((g) => g['name'] as String)], (v) {
            setState(() => _selectedGame = v!);
            _fetchChallenges();
          }),
          _buildFilterBox('ENTRY FEE RANGE', 'Any Amount'),
          _buildFilterBox('DATE RANGE', 'mm/dd/yyyy', icon: Icons.calendar_today_outlined),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: StitchTheme.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, color: Colors.white)))).toList(),
              onChanged: onChanged,
              dropdownColor: StitchTheme.surface,
              icon: const Icon(Icons.keyboard_arrow_down, color: StitchTheme.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBox(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: StitchTheme.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Row(
            children: [
              Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.white70))),
              Icon(icon ?? Icons.keyboard_arrow_down, color: StitchTheme.textMuted, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeList() {
    if (_challenges.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(Icons.sports_esports_outlined, size: 64, color: Colors.white10),
              SizedBox(height: 16),
              Text('No challenges found for the selected filters.', style: TextStyle(color: StitchTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: StitchTheme.surface, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          if (!isMobile) _buildTableHeader(),
          ...List.generate(_challenges.length, (index) => _buildChallengeRow(_challenges[index], isMobile)),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('CHALLENGE ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: StitchTheme.textMuted))),
          Expanded(flex: 2, child: Text('CREATOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: StitchTheme.textMuted))),
          Expanded(flex: 2, child: Text('OPPONENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: StitchTheme.textMuted))),
          Expanded(flex: 1, child: Text('ENTRY FEE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: StitchTheme.textMuted))),
          Expanded(flex: 1, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: StitchTheme.textMuted))),
          Expanded(flex: 2, child: Text('CREATED TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: StitchTheme.textMuted))),
          SizedBox(width: 80, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: StitchTheme.textMuted), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildChallengeRow(Map<String, dynamic> c, bool isMobile) {
    if (isMobile) return _buildMobileCard(c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        children: [
          Expanded(
            flex: 2, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#CH-${c['id'].toString().substring(0, 4)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                Text('${c['games']?['name']} • ${c['mode']}', style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted)),
              ],
            ),
          ),
          Expanded(flex: 2, child: _buildPlayerCell(c['creator'])),
          Expanded(flex: 2, child: c['opponent'] == null ? const Text('Waiting...', style: TextStyle(color: StitchTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 13)) : _buildPlayerCell(c['opponent'])),
          Expanded(
            flex: 1, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹${c['entry_fee']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${(c['entry_fee'] * 2 * 0.9).toStringAsFixed(0)} Prize', style: const TextStyle(fontSize: 10, color: StitchTheme.success)),
              ],
            ),
          ),
          Expanded(flex: 1, child: _buildStatusChip(c['status'])),
          Expanded(
            flex: 2, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(c['created_at'])), style: const TextStyle(fontSize: 12)),
                Text(DateFormat('HH:mm a').format(DateTime.parse(c['created_at'])), style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted)),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (c['status'] == 'dispute') 
                  _buildIconButton(Icons.gavel_rounded, Colors.redAccent, () => context.push('/dispute_detail/${c['id']}'))
                else
                  _buildIconButton(Icons.visibility_outlined, Colors.white, () => context.push('/dispute_detail/${c['id']}')),
                const SizedBox(width: 8),
                _buildIconButton(Icons.block_outlined, Colors.white10, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Column(
        children: [
          Row(
            children: [
              Text('#CH-${c['id'].toString().substring(0, 4)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const Spacer(),
              _buildStatusChip(c['status']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPlayerCell(c['creator'])),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white10))),
              Expanded(child: c['opponent'] == null ? const Text('Waiting...', style: TextStyle(color: StitchTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 13)) : _buildPlayerCell(c['opponent'])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
               Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Game: ${c['games']?['name']}', style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted)),
                  Text('Entry: ₹${c['entry_fee']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              if (c['status'] == 'dispute')
                 StitchButton(
                  text: 'Resolve', 
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  textColor: Colors.redAccent,
                  onPressed: () => context.push('/dispute_detail/${c['id']}'),
                )
              else
                StitchButton(
                  text: 'View', 
                  backgroundColor: Colors.white.withOpacity(0.05),
                  textColor: Colors.white70,
                  onPressed: () => context.push('/dispute_detail/${c['id']}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCell(Map<String, dynamic>? player) {
    if (player == null) return const SizedBox();
    return Row(
      children: [
        StitchAvatar(
          radius: 14,
          name: player['username'] ?? 'U',
          avatarUrl: player['avatar_url'],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(player['username'] ?? 'User', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
              const Text('Lv. 45', style: TextStyle(fontSize: 9, color: StitchTheme.textMuted)), // Example level
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    switch (status.toLowerCase()) {
      case 'open': color = Colors.blue; break;
      case 'accepted': color = Colors.cyan; break;
      case 'ready': color = Colors.amber; break;
      case 'ongoing': color = Colors.green; break;
      case 'completed': color = Colors.grey; break;
      case 'dispute': color = Colors.red; break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Text('Showing 1 to 10 of 1,284 entries', style: TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
          const Spacer(),
          _buildPageButton('Previous', false),
          const SizedBox(width: 8),
          _buildPageButton('1', true),
          const SizedBox(width: 8),
          _buildPageButton('2', false),
          const SizedBox(width: 8),
          _buildPageButton('3', false),
          const SizedBox(width: 4),
          const Text('...', style: TextStyle(color: StitchTheme.textMuted)),
          const SizedBox(width: 4),
          _buildPageButton('Next', false),
        ],
      ),
    );
  }

  Widget _buildPageButton(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.greenAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? Colors.greenAccent : Colors.white10),
      ),
      child: Text(text, style: TextStyle(color: active ? Colors.black : StitchTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
