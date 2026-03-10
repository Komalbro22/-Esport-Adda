import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ChallengeAnalyticsScreen extends StatefulWidget {
  const ChallengeAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<ChallengeAnalyticsScreen> createState() => _ChallengeAnalyticsScreenState();
}

class _ChallengeAnalyticsScreenState extends State<ChallengeAnalyticsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  double _totalCommission = 0;
  double _todayCommission = 0;
  int _totalChallenges = 0;
  int _completedChallenges = 0;
  int _disputedChallenges = 0;
  List<Map<String, dynamic>> _recentEarnings = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      // Total Commission
      final comms = await _supabase.from('wallet_transactions')
          .select('amount')
          .eq('type', 'challenge_commission')
          .eq('status', 'success');
      
      // Today's Commission
      final todayComms = await _supabase.from('wallet_transactions')
          .select('amount')
          .eq('type', 'challenge_commission')
          .eq('status', 'success')
          .gte('created_at', todayStart);

      // Challenge Stats
      final challengeStats = await _supabase.from('challenges').select('status');

      // Recent Commissions
      final recent = await _supabase.from('wallet_transactions')
          .select('*, users!user_id(username)')
          .eq('type', 'challenge_commission')
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _totalCommission = (comms as List).fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));
          _todayCommission = (todayComms as List).fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));
          
          final challenges = challengeStats as List;
          _totalChallenges = challenges.length;
          _completedChallenges = challenges.where((c) => c['status'] == 'completed').length;
          _disputedChallenges = challenges.where((c) => c['status'] == 'dispute').length;
          
          _recentEarnings = List<Map<String, dynamic>>.from(recent);
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

    final disputeRate = _totalChallenges > 0 ? (_disputedChallenges / _totalChallenges * 100).toStringAsFixed(1) : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge Analytics'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAnalytics,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildEarningCard(),
            const SizedBox(height: 24),
            const Text('CHALLENGE PERFORMANCE', style: TextStyle(fontWeight: FontWeight.w900, color: StitchTheme.textMuted, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 16),
            StitchGrid(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              children: [
               _buildMetricCard('Total Matches', _totalChallenges.toString(), Icons.sports_esports, Colors.blue),
               _buildMetricCard('Completed', _completedChallenges.toString(), Icons.check_circle, Colors.green),
               _buildMetricCard('Disputes', _disputedChallenges.toString(), Icons.gavel, Colors.orange),
               _buildMetricCard('Dispute Rate', '$disputeRate%', Icons.analytics, Colors.purple),
              ],
            ),
            const SizedBox(height: 32),
            const Text('RECENT COMMISSIONS', style: TextStyle(fontWeight: FontWeight.w900, color: StitchTheme.textMuted, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 16),
            ..._recentEarnings.map((e) => _buildRecentEarning(e)).toList(),
            if (_recentEarnings.isEmpty) const Center(child: Text('No earnings found', style: TextStyle(color: StitchTheme.textMuted))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [StitchTheme.primary, StitchTheme.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: StitchTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOTAL COMMISSION EARNED', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text('₹${_totalCommission.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildSimpleStat('Today', '₹${_todayCommission.toStringAsFixed(2)}'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.greenAccent, size: 16),
                    SizedBox(width: 4),
                    Text('Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return StitchCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildRecentEarning(Map<String, dynamic> e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: StitchTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Commission', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(e['created_at'])), style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted)),
              ],
            ),
          ),
          Text('+₹${e['amount']}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
