import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      debugPrint('Fetching dispute details for ID: ${widget.challengeId}');
      final challengeData = await _supabase.from('challenges')
          .select('*, creator:users!creator_id(username, fair_score), opponent:users!opponent_id(username, fair_score), games(name)')
          .eq('id', widget.challengeId)
          .single();
      
      debugPrint('Challenge data loaded: ${challengeData['id']}');
      
      final resultsData = await _supabase.from('challenge_results')
          .select('*, user:users!user_id(username)')
          .eq('challenge_id', widget.challengeId);
      
      debugPrint('Found ${resultsData.length} results');
      
      if (mounted) {
        setState(() {
          _challenge = challengeData;
          _results = List<Map<String, dynamic>>.from(resultsData as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dispute details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: StitchLoading()));
    if (_challenge == null) return const Scaffold(body: Center(child: Text('Dispute not found')));

    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(_challenge!['status'] == 'dispute' ? 'Resolve Dispute' : 'Challenge Details', style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
            tooltip: 'Fair Play Guidelines',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMatchSummary(),
            const SizedBox(height: 48),
            Row(
              children: [
                const Icon(Icons.compare_rounded, color: StitchTheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  _challenge!['status'] == 'dispute' ? 'EVIDENCE COMPARISON' : 'MATCH RESULTS', 
                  style: const TextStyle(fontWeight: FontWeight.w900, color: StitchTheme.textMuted, fontSize: 11, letterSpacing: 2)
                ),
                const Spacer(),
                Text('${_results.length}/2 Submissions', style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 24),
            
            if (isWide && _results.length == 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildResultCard(_results[0], isSideBySide: true)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildResultCard(_results[1], isSideBySide: true)),
                ],
              )
            else
              ..._results.map((r) => _buildResultCard(r)).toList(),
            
            if (_results.isEmpty) 
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    _challenge!['status'] == 'dispute' ? 'No evidence submitted yet' : 'No results submitted yet', 
                    style: const TextStyle(color: StitchTheme.textMuted)
                  )
                )
              ),
              
            if (_challenge!['status'] == 'dispute') ...[
              const SizedBox(height: 60),
              _buildActionButtons(),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPlayerHeader(_challenge!['creator']['username'], 'Creator'),
              const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.orangeAccent)),
              _buildPlayerHeader(_challenge!['opponent']['username'], 'Opponent'),
            ],
          ),
          const Divider(height: 40, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Entry', '₹${_challenge!['entry_fee']}'),
              _buildStat('Game', _challenge!['games']['name']),
              _buildStat('Mode', _challenge!['mode']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r, {bool isSideBySide = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r['user']['username'], style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.primary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: r['result'] == 'win' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r['result'].toString().toUpperCase(),
                  style: TextStyle(color: r['result'] == 'win' ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (r['screenshot_url'] != null)
            GestureDetector(
              onTap: () => _viewFullImage(r['screenshot_url']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: r['screenshot_url'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const StitchShimmer(height: 200),
                ),
              ),
            ),
          if (r['video_url'] != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(r['video_url'])),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('View Video Proof', style: TextStyle(fontWeight: FontWeight.bold))),
                    const Icon(Icons.open_in_new, size: 16, color: Colors.white38),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton('Award Creator: ${_challenge!['creator']['username']}', Colors.green, () => _resolve('award_winner', _challenge!['creator_id'])),
        const SizedBox(height: 12),
        _buildActionButton('Award Opponent: ${_challenge!['opponent']['username']}', Colors.green, () => _resolve('award_winner', _challenge!['opponent_id'])),
        const SizedBox(height: 12),
        _buildActionButton('Refund Both Players', Colors.orange, () => _resolve('refund')),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _resolve(String action, [String? winnerId]) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StitchTheme.surface,
        title: const Text('Confirm Resolution'),
        content: Text('Are you sure you want to ${action.replaceAll('_', ' ')}? Funds will be distributed immediately and result locked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: StitchTheme.primary),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      StitchSnackbar.showLoading(context, 'Resolving match...');
      final response = await _supabase.functions.invoke('manage_challenges', body: {
        'action': 'resolve_dispute',
        'challenge_id': widget.challengeId,
        'winner_id': winnerId,
        'resolution': action,
      });

      if (response.status != 200) throw response.data['error'];

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Dispute resolved successfully');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString());
    }
  }

  void _viewFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: CachedNetworkImage(imageUrl: url)),
            Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader(String name, String label) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
