import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class FairPlayLeaderboardScreen extends StatefulWidget {
  const FairPlayLeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<FairPlayLeaderboardScreen> createState() => _FairPlayLeaderboardScreenState();
}

class _FairPlayLeaderboardScreenState extends State<FairPlayLeaderboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _topPlayers = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final data = await _supabase.from('users')
          .select('id, username, fair_score, avatar_url')
          .order('fair_score', ascending: false)
          .limit(50);
      
      if (mounted) {
        setState(() {
          _topPlayers = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fair Play Leaderboard'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _topPlayers.length,
            itemBuilder: (context, index) {
              final player = _topPlayers[index];
              final score = player['fair_score'] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: StitchTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: StitchTheme.primary)),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => context.push('/public_profile/${player['id']}'),
                      child: StitchAvatar(
                        radius: 20,
                        name: player['username'] ?? 'User',
                        avatarUrl: player['avatar_url'],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(player['username'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold))),
                    _buildScoreBadge(score),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildScoreBadge(int score) {
    Color color = Colors.greenAccent;
    if (score < 60) color = Colors.orangeAccent;
    if (score < 30) color = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
