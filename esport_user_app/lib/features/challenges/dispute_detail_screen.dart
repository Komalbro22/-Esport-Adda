import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DisputeDetailScreen extends StatefulWidget {
  final String challengeId;

  const DisputeDetailScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _challenge;
  Map<String, dynamic>? _yourResult;
  Map<String, dynamic>? _opponentResult;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final challengeRes = await _supabase.from('challenges')
          .select('*, creator:users!creator_id(username), opponent:users!opponent_id(username), games(name)')
          .eq('id', widget.challengeId)
          .single();

      final resultsRes = await _supabase.from('challenge_results')
          .select('*')
          .eq('challenge_id', widget.challengeId);

      final results = resultsRes as List;
      
      setState(() {
        _challenge = challengeRes;
        _yourResult = results.firstWhere((r) => r['user_id'] == user.id, orElse: () => null);
        _opponentResult = results.firstWhere((r) => r['user_id'] != user.id, orElse: () => null);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load dispute details');
        context.pop();
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Dispute Notification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 32),
            _buildMatchInfo(),
            const SizedBox(height: 32),
            _buildProofSection(),
            const SizedBox(height: 40),
            _buildSupportButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.amber.withOpacity(0.1),
            border: Border.all(color: Colors.amber.withOpacity(0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.05),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 56),
        ),
        const SizedBox(height: 24),
        const Text(
          'Dispute Detected',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
        ),
        const SizedBox(height: 12),
        const Text(
          'Result dispute detected. Admin will review the\nmatch evidence shortly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sentiment_neutral_rounded, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text(
                'UNDER REVIEW',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENT MATCH', style: TextStyle(color: Color(0xFF00B0FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(
                  '${_challenge!['games']['name']} Battle',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text('ID: #${_challenge!['id'].toString().substring(0, 8).toUpperCase()}', style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.sports_esports_rounded, color: Colors.deepPurpleAccent, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildProofSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF00C853), size: 20),
            SizedBox(width: 12),
            Text('SUBMITTED PROOF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildProofCard('Your Proof', _yourResult?['screenshot_url']),
            const SizedBox(width: 16),
            _buildProofCard('Opponent\'s Proof', _opponentResult?['screenshot_url']),
          ],
        ),
      ],
    );
  }

  Widget _buildProofCard(String label, String? imageUrl) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Stack(
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: Colors.white10),
                    ),
                  )
                else
                  const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.white10, size: 40)),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00C853), size: 14),
                      const SizedBox(width: 6),
                      Text('VIEW FULL', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSupportButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: () => context.push('/support'),
        icon: const Icon(Icons.support_agent_rounded, size: 24),
        label: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 4,
          shadowColor: const Color(0xFF7C4DFF).withOpacity(0.3),
        ),
      ),
    );
  }
}
