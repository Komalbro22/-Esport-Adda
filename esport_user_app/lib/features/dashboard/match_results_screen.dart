import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class MatchResultsScreen extends StatefulWidget {
  final String tournamentId;
  const MatchResultsScreen({super.key, required this.tournamentId});

  @override
  State<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends State<MatchResultsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic>? _myPerformance;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    try {
      final user = _supabase.auth.currentUser;
      
      final data = await _supabase
          .from('joined_teams')
          .select('*, users(name, username, avatar_url)')
          .eq('tournament_id', widget.tournamentId)
          .order('rank', ascending: true);

      if (mounted) {
        setState(() {
          _leaderboard = List<Map<String, dynamic>>.from(data);
          
          if (user != null) {
            try {
              _myPerformance = _leaderboard.firstWhere((team) => team['user_id'] == user.id);
            } catch (e) {
              _myPerformance = null;
            }
          }
          
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

    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('Match Results', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_myPerformance != null) ...[
              const Text('Your Performance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PerformanceCircle(
                    value: '#${_myPerformance!['rank'] ?? '-'}',
                    label: 'Rank',
                    color: Colors.cyanAccent,
                  ),
                  _PerformanceCircle(
                    value: '${_myPerformance!['kills'] ?? '0'}',
                    label: 'Total Kills',
                    color: Colors.cyanAccent,
                  ),
                  _PerformanceCircle(
                    value: '₹${_myPerformance!['total_prize'] ?? '0'}',
                    label: 'Prize Won',
                    color: Colors.cyanAccent,
                    isHighlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            const Text('Global Leaderboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            
            if (_leaderboard.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No results recorded yet.', style: TextStyle(color: StitchTheme.textMuted))))
            else
              ...List.generate(_leaderboard.length, (index) {
                final team = _leaderboard[index];
                final user = team['users'] ?? {};
                final rank = team['rank'] ?? (index + 1);
                final kills = team['kills'] ?? 0;
                final prize = team['total_prize'] ?? 0;
                
                final isMe = _myPerformance != null && team['id'] == _myPerformance!['id'];

                // Podium Colors
                Color borderColor = Colors.white.withValues(alpha: 0.1);
                Color iconColor = Colors.white54;
                IconData rankIcon = Icons.military_tech_rounded;
                bool isTop3 = true;
                
                if (rank == 1) {
                  borderColor = Colors.amber;
                  iconColor = Colors.amber;
                  rankIcon = Icons.emoji_events;
                } else if (rank == 2) {
                  borderColor = Colors.grey.shade400;
                  iconColor = Colors.grey.shade400;
                } else if (rank == 3) {
                  borderColor = Colors.orangeAccent;
                  iconColor = Colors.orangeAccent;
                } else {
                  isTop3 = false;
                  borderColor = Colors.white.withValues(alpha: 0.05);
                }

                if (isMe) {
                  borderColor = const Color(0xFF9042FF);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF9042FF).withValues(alpha: 0.1) : const Color(0xFF1A1C24),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: isTop3 || isMe ? [
                      BoxShadow(
                        color: borderColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ] : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: isTop3 
                            ? Icon(rankIcon, color: iconColor, size: 28)
                            : Text(rank.toString(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF2A2D36),
                        backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                        child: user['avatar_url'] == null 
                          ? Text((user['name'] ?? 'P')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'You (${user['name'] ?? 'Player'})' : (user['name'] ?? 'Player'),
                              style: TextStyle(
                                color: isTop3 ? iconColor : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('$kills Kills', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(
                        '₹$prize',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF9042FF),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9042FF).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                StitchSnackbar.showSuccess(context, 'Result summary copied to clipboard!');
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Share Results', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PerformanceCircle extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isHighlight;

  const _PerformanceCircle({
    required this.value,
    required this.label,
    required this.color,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C24),
        shape: BoxShape.circle,
        border: Border.all(
          color: isHighlight ? color.withValues(alpha: 0.5) : const Color(0xFF9042FF).withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: isHighlight ? [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ] : [
          BoxShadow(
            color: const Color(0xFF9042FF).withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
