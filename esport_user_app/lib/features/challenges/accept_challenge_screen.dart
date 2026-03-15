import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'reputation_badge_widget.dart';

class AcceptChallengeScreen extends StatefulWidget {
  final String challengeId;

  const AcceptChallengeScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  State<AcceptChallengeScreen> createState() => _AcceptChallengeScreenState();
}

class _AcceptChallengeScreenState extends State<AcceptChallengeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _challenge;
  int _userFairScore = 100;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final results = await Future.wait([
        _supabase.from('challenges')
            .select('*, creator:users!creator_id(username, fair_score, avatar_url), games(name)')
            .eq('id', widget.challengeId)
            .single(),
        _supabase.from('users').select('fair_score').eq('id', user.id).single(),
      ]);

      if (mounted) {
        setState(() {
          _challenge = results[0] as Map<String, dynamic>;
          _userFairScore = (results[1] as Map<String, dynamic>)['fair_score'] ?? 100;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load challenge details');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F111A),
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    if (_challenge == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F111A),
        body: Center(child: Text('Challenge not found', style: TextStyle(color: Colors.white))),
      );
    }

    final double prizePool = _challenge!['entry_fee'] * 2 * (1 - (_challenge!['commission_percent'] / 100));
    final int minScore = _challenge!['min_fair_score'] ?? 0;
    final bool canJoin = _userFairScore >= minScore;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Accept Challenge',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreatorCard(),
            const SizedBox(height: 24),
            _buildMatchSummary(prizePool),
            const SizedBox(height: 32),
            const Text(
              'BATTLE RULES',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            _buildRulesList(),
            const SizedBox(height: 24),
            _buildFairPlayCheck(minScore),
            const SizedBox(height: 32),
            _buildAcceptButton(canJoin),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorCard() {
    final creator = _challenge!['creator'];
    final score = creator['fair_score'] ?? 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D).withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF00E5FF), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: StitchAvatar(
                  radius: 35,
                  name: creator['username'] ?? 'User',
                  avatarUrl: creator['avatar_url'],
                  backgroundColor: const Color(0xFF1A1D2D),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1A1D2D), width: 2),
                  ),
                  child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      creator['username'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ReputationBadge(score: score, fontSize: 10),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24)),
                    const SizedBox(width: 8),
                    const Text('4.8 Rating', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchSummary(double prizePool) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.sports_esports_rounded, color: Colors.blueAccent.withOpacity(0.8), size: 24),
              const SizedBox(width: 12),
              const Text(
                'Match Summary',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildSummaryItem('MODE', _challenge!['mode'], isHighlight: false),
              _buildSummaryItem('GAME', _challenge!['games']['name'], isHighlight: false),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSummaryItem('ENTRY FEE', '₹${_challenge!['entry_fee']}', isHighlight: true, highlightColor: const Color(0xFF00C853)),
              _buildSummaryItem(
                'PRIZE POOL', 
                '₹${prizePool.toStringAsFixed(0)}', 
                isHighlight: true, 
                highlightColor: const Color(0xFF00B0FF),
                subValue: '(${(100 - _challenge!['commission_percent']).toStringAsFixed(0)}% Payout)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {required bool isHighlight, Color? highlightColor, String? subValue}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isHighlight ? highlightColor : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              if (subValue != null) ...[
                const SizedBox(width: 4),
                Text(subValue, style: const TextStyle(color: Colors.white12, fontSize: 9)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    final rulesText = _challenge!['rules']?.toString() ?? '';
    final List<Map<String, dynamic>> rules;

    if (rulesText.trim().isNotEmpty) {
      rules = rulesText.trim().split('\n').where((s) => s.isNotEmpty).map((r) => {
        'icon': Icons.check_circle_outline_rounded, 
        'text': r
      }).toList();
    } else {
      rules = [
        {'icon': Icons.block_flipped, 'text': 'No Grenades or Launcher usage allowed'},
        {'icon': Icons.map_rounded, 'text': 'Standard Map: Bermuda Remastered'},
        {'icon': Icons.laptop_windows_rounded, 'text': 'No Emulator - Mobile players only'},
      ];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: rules.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(r['icon'] as IconData, size: 18, color: (r['icon'] == Icons.check_circle_outline_rounded) ? Colors.blueAccent : Colors.redAccent.withOpacity(0.8)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  r['text'] as String,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildFairPlayCheck(int minScore) {
    final double progress = (_userFairScore / 100).clamp(0.0, 1.0);
    final bool isSafe = _userFairScore >= minScore;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF00B0FF), size: 20),
                  const SizedBox(width: 12),
                  const Text('Fair Play Check', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Text('Min Score: $minScore+', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(isSafe ? const Color(0xFF00C853) : Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$_userFairScore/100',
                style: TextStyle(
                  color: isSafe ? const Color(0xFF00C853) : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isSafe ? 'Your current fair play score exceeds requirements.' : 'You do not meet the fair play requirements to join.',
            style: const TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptButton(bool canJoin) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: canJoin ? _handleAccept : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 8,
          shadowColor: const Color(0xFF00C853).withOpacity(0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch_rounded, size: 24),
            const SizedBox(width: 12),
            const Text(
              'CONFIRM & ACCEPT',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAccept() async {
    try {
      StitchSnackbar.showLoading(context, 'Joining match...');
      final response = await _supabase.functions.invoke(
        'manage_challenges',
        body: { 'action': 'accept_challenge', 'challenge_id': widget.challengeId },
      );

      if (response.status != 200) throw Exception(response.data['error'] ?? 'Failed to join');

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Successfully joined!');
        context.pushReplacement('/challenge_detail/${widget.challengeId}');
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString());
    }
  }
}
