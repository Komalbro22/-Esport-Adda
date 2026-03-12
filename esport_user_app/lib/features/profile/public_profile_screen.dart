import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Check if current user is admin (wrapped in try-catch to avoid breaking the screen)
      try {
        final adminCheck = await _supabase
            .from('admin_users')
            .select()
            .eq('user_id', currentUser.id)
            .maybeSingle();
        _isAdmin = adminCheck != null;
      } catch (e) {
        debugPrint('Admin check failed: $e');
        _isAdmin = false;
      }

      // Fetch target user info
      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();

      // Fetch stats
      final joinedTeamsData = await _supabase
          .from('joined_teams')
          .select('rank, kills')
          .eq('user_id', widget.userId);
          
      int matchesPlayed = 0;
      int totalKills = 0;
      int totalWins = 0;
      
      if (joinedTeamsData != null) {
        matchesPlayed = (joinedTeamsData as List).length;
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
      debugPrint('Error fetching public profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userData = null;
        });
        StitchSnackbar.showError(context, 'Profile not found or connection error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: StitchLoading()));
    if (_userData == null) return const Scaffold(body: Center(child: StitchError(message: 'User not found')));

    final bool showBio = _isAdmin || (_userData!['show_bio'] ?? true);
    final bool showPhone = _isAdmin || (_userData!['show_phone'] ?? false);
    final bool showSocials = _isAdmin || (_userData!['show_socials'] ?? true);
    final bool hideAvatar = !(_isAdmin) && (_userData!['hide_avatar'] ?? false);

    final String? avatarUrl = hideAvatar ? null : _userData!['avatar_url'];
    final Map<String, dynamic> social = _userData!['social_links'] as Map<String, dynamic>? ?? {};

    final joinedDate = _userData!['created_at'] != null 
        ? DateFormat('MMMM yyyy').format(DateTime.parse(_userData!['created_at']))
        : 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text('${_userData!['name'] ?? 'User'}\'s Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00FBFF), Color(0xFF6E00FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                    child: StitchAvatar(
                      radius: 50,
                      name: _userData!['name'] ?? _userData!['username'] ?? 'User',
                      avatarUrl: avatarUrl,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 60),

            Text(
              _userData!['name'] ?? 'User Name',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '@${_userData!['username'] ?? 'username'}',
              style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 16),
            
            _buildFairScoreBadge(_userData!['fair_score'] ?? 100),

            const SizedBox(height: 24),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatCard('Matches', _stats?['matches_played']?.toString() ?? '0', Icons.sports_esports),
                  const SizedBox(width: 8),
                  _buildStatCard('Wins', _stats?['total_wins']?.toString() ?? '0', Icons.emoji_events),
                  const SizedBox(width: 8),
                  _buildStatCard('Kills', _stats?['total_kills']?.toString() ?? '0', Icons.track_changes_rounded),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StitchCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem(Icons.calendar_today_rounded, 'Member Since', joinedDate),
                    if (showPhone && _userData!['phone'] != null && _userData!['phone']!.isNotEmpty)
                      _buildInfoItem(Icons.phone_android_rounded, 'Phone Number', _userData!['phone']),
                    if (showBio && _userData!['bio'] != null && _userData!['bio']!.isNotEmpty) ...[
                      const Divider(height: 24, color: Colors.white10),
                      const Text('BIO', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(_userData!['bio']!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Socials
            if (showSocials && social.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StitchCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SOCIAL LINKS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      if (social['instagram'] != null && social['instagram']!.isNotEmpty)
                        _buildSocialItem(Icons.camera_alt_rounded, 'Instagram', social['instagram']),
                      if (social['discord'] != null && social['discord']!.isNotEmpty)
                        _buildSocialItem(Icons.discord_rounded, 'Discord', social['discord']),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFairScoreBadge(int score) {
    Color color = const Color(0xFF00E676);
    if (score < 40) color = Colors.redAccent;
    else if (score < 80) color = Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        'FAIR SCORE: $score',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StitchTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: StitchTheme.primary, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: StitchTheme.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(color: StitchTheme.textMuted)),
        ],
      ),
    );
  }
}
