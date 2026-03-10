import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Fetch user basic info
      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      // Fetch stats dynamically from joined_teams to ensure accuracy
      // matches_played = count of rows
      // total_kills = sum of kills
      // total_wins = count of rows where rank == 1
      final joinedTeamsData = await _supabase
          .from('joined_teams')
          .select('rank, kills')
          .eq('user_id', user.id);
          
      int matchesPlayed = 0;
      int totalKills = 0;
      int totalWins = 0;
      
      if (joinedTeamsData != null) {
        matchesPlayed = joinedTeamsData.length;
        for (var row in joinedTeamsData) {
          totalKills += (row['kills'] as num?)?.toInt() ?? 0;
          if (row['rank'] == 1) {
            totalWins++;
          }
        }
      }

      final computedStats = {
        'matches_played': matchesPlayed,
        'total_kills': totalKills,
        'total_wins': totalWins,
      };

      if (mounted) {
        setState(() {
          _userData = userData;
          _stats = computedStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: StitchLoading());
    if (_userData == null) return const Center(child: StitchError(message: 'Failed to load profile'));

    final joinedDate = _userData!['created_at'] != null 
        ? DateFormat('MMMM yyyy').format(DateTime.parse(_userData!['created_at']))
        : 'Unknown';

    return RefreshIndicator(
      onRefresh: _fetchProfileData,
      color: StitchTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // 1. Profile Header with Curved Background
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00FBFF), Color(0xFF6E00FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  child: _buildAvatar(),
                ),
              ],
            ),
            
            const SizedBox(height: 70),
            
            // 2. Name and Info
            Text(
              _userData!['name'] ?? 'User Name',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text(
              '@${_userData!['username'] ?? 'username'}',
              style: const TextStyle(color: Color(0xFF00FBFF), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white54),
                const SizedBox(width: 8),
                Text(
                  'Gamer since $joinedDate',
                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 3. Fair Score Badge
            _buildFairScoreBadge(_userData!['fair_score'] ?? 100),
            
            const SizedBox(height: 16),
            
            // 4. Edit Profile Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await context.push('/edit_profile');
                    if (result == true) {
                      setState(() => _isLoading = true);
                      _fetchProfileData();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00FBFF), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text(
                    'EDIT PROFILE',
                    style: TextStyle(color: Color(0xFF00FBFF), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 5. Stats Cards Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatCard('Matches', _stats?['matches_played']?.toString() ?? '0', Icons.sports_esports),
                  const SizedBox(width: 12),
                  _buildStatCard('Wins', _stats?['total_wins']?.toString() ?? '0', Icons.emoji_events),
                  const SizedBox(width: 12),
                  _buildStatCard('Kills', _stats?['total_kills']?.toString() ?? '0', Icons.track_changes_rounded),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 6. Menu List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildMenuListItem(Icons.sports_esports, 'My Matches', () => context.push('/my_matches')),
                  _buildMenuListItem(Icons.verified_rounded, 'Fair Play Leaderboard', () => context.push('/fair_play_leaderboard')),
                  _buildMenuListItem(Icons.bar_chart_rounded, 'Global Leaderboard', () => context.push('/global_leaderboard')),
                  _buildMenuListItem(Icons.share_rounded, 'Refer & Earn', () => context.push('/referral')),
                  _buildMenuListItem(Icons.settings, 'Game Settings', () => context.push('/settings')),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () async {
                  await _supabase.auth.signOut();
                  if (mounted) context.go('/login');
                },
                child: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        boxShadow: [
          BoxShadow(color: const Color(0xFF00FBFF).withOpacity(0.5), blurRadius: 20, spreadRadius: 0),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
        ),
        child: CircleAvatar(
          radius: 54,
          backgroundColor: const Color(0xFF1B1B1B),
          backgroundImage: _userData!['avatar_url'] != null 
              ? NetworkImage(_userData!['avatar_url']) 
              : null,
          child: _userData!['avatar_url'] == null 
              ? const Icon(Icons.person, size: 54, color: Colors.white24) 
              : null,
        ),
      ),
    );
  }

  Widget _buildFairScoreBadge(int score) {
    Color color = const Color(0xFF00E676);
    String label = 'TRUSTED';
    if (score < 40) {
      color = Colors.redAccent;
      label = 'RISK';
    } else if (score < 80) {
      color = Colors.orangeAccent;
      label = 'FAIR';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            'FAIR SCORE: $score | $label',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF00FBFF), size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuListItem(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF00FBFF), size: 24),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
