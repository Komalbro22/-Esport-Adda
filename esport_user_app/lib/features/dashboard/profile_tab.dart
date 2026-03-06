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

    return RefreshIndicator(
      onRefresh: _fetchProfileData,
      color: StitchTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Profile Header with Background
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: StitchTheme.primaryGradient,
                  ),
                  child: Opacity(
                    opacity: 0.1,
                    child: Icon(Icons.videogame_asset_rounded, size: 200, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  child: _buildAvatar(),
                ),
              ],
            ),
            
            const SizedBox(height: 60),
            
            _buildProfileInfo(),
            
            const SizedBox(height: 32),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildStats(),
                  const SizedBox(height: 32),
                  _buildMenu(),
                  const SizedBox(height: 40),
                  StitchButton(
                    text: 'LOGOUT',
                    onPressed: () async {
                      await _supabase.auth.signOut();
                      if (mounted) context.go('/login');
                    },
                    backgroundColor: Colors.red.withOpacity(0.05),
                    textColor: Colors.red,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: StitchTheme.background, width: 6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
        ],
      ),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: StitchTheme.surfaceHighlight,
        backgroundImage: _userData!['avatar_url'] != null 
            ? NetworkImage(_userData!['avatar_url']) 
            : null,
        child: _userData!['avatar_url'] == null 
            ? const Icon(Icons.person, size: 60, color: StitchTheme.primary) 
            : null,
      ),
    );
  }

  Widget _buildProfileInfo() {
    final joinedDate = _userData!['created_at'] != null 
        ? DateFormat('MMMM yyyy').format(DateTime.parse(_userData!['created_at']))
        : 'Unknown';

    return Column(
      children: [
        Text(
          _userData!['name'] ?? 'User Name',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: StitchTheme.textMain, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          '@${_userData!['username'] ?? 'username'}',
          style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: StitchTheme.textMuted.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text(
              'Gamer since $joinedDate',
              style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          child: StitchButton(
            text: 'EDIT PROFILE',
            isSecondary: true,
            onPressed: () async {
              final result = await context.push('/edit_profile');
              if (result == true) {
                setState(() => _isLoading = true);
                _fetchProfileData();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(child: StitchStatCard(title: 'Matches', value: _stats?['matches_played']?.toString() ?? '0', icon: Icons.sports_esports)),
        const SizedBox(width: 8),
        Expanded(child: StitchStatCard(title: 'Wins', value: _stats?['total_wins']?.toString() ?? '0', color: StitchTheme.success, icon: Icons.emoji_events)),
        const SizedBox(width: 8),
        Expanded(child: StitchStatCard(title: 'Kills', value: _stats?['total_kills']?.toString() ?? '0', color: StitchTheme.accent, icon: Icons.my_location)),
      ],
    );
  }

  Widget _buildMenu() {
    return Column(
      children: [
        _buildMenuItem(Icons.sports_esports_outlined, 'My Matches', () => context.push('/my_matches')),
        _buildMenuItem(Icons.share_outlined, 'Refer & Earn', () => context.push('/referral')),
        _buildMenuItem(Icons.settings_outlined, 'Game Settings', () => context.push('/settings')),
        _buildMenuItem(Icons.help_outline, 'Support', () => context.push('/support')),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StitchCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: StitchTheme.primary),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 16, color: StitchTheme.textMain, fontWeight: FontWeight.w500)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 14, color: StitchTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
