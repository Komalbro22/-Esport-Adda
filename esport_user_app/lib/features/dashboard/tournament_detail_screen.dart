import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({Key? key, required this.tournamentId}) : super(key: key);

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _tournament;
  bool _isLoading = true;
  bool _isJoining = false;
  bool _hasJoined = false;
  Map<String, dynamic>? _joinedTeamData;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  List<Map<String, dynamic>> _participants = [];

  Future<void> _fetchDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final futures = await Future.wait([
        _supabase.from('tournaments').select('*, games(name)').eq('id', widget.tournamentId).single(),
        _supabase.from('joined_teams').select('*').eq('tournament_id', widget.tournamentId).eq('user_id', user.id).maybeSingle(),
        _supabase.from('joined_teams').select('users(name, username)').eq('tournament_id', widget.tournamentId).limit(50),
      ]);

      if (mounted) {
        setState(() {
          _tournament = futures[0] as Map<String, dynamic>;
          _joinedTeamData = futures[1] as Map<String, dynamic>?;
          _participants = List<Map<String, dynamic>>.from(futures[2] as List);
          _hasJoined = _joinedTeamData != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load details');
      }
    }
  }

  Future<void> _navigateToJoin() async {
    final success = await context.push<bool?>('/join_tournament_form/${widget.tournamentId}');
    if (success == true) {
      _fetchDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());
    if (_tournament == null) return Scaffold(appBar: AppBar(), body: const StitchError(message: 'Not found'));

    final t = _tournament!;
    final status = t['status'];
    final bool isFull = t['joined_slots'] >= t['total_slots'];

    return Scaffold(
      backgroundColor: StitchTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                StitchTheme.background.withOpacity(0.8),
                StitchTheme.background.withOpacity(0.0),
              ],
            ),
          ),
        ),
        title: Text(t['title'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Scrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
          // Banner Section with Live Indicator
          Stack(
            children: [
              if (t['banner_url'] != null && t['banner_url'].toString().isNotEmpty)
                Image.network(
                  t['banner_url'], 
                  height: 280, 
                  width: double.infinity, 
                  fit: BoxFit.cover, 
                  errorBuilder: (c,e,s) => Container(height: 280, color: StitchTheme.surfaceHighlight, child: const Icon(Icons.image_not_supported, color: StitchTheme.textMuted))
                )
              else
                Container(height: 280, decoration: const BoxDecoration(gradient: StitchTheme.primaryGradient)),
              
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        StitchTheme.background.withOpacity(0.5),
                        StitchTheme.background,
                      ],
                    ),
                  ),
                ),
              ),
              
              if (status == 'ongoing')
                const Positioned(
                  top: 100,
                  right: 16,
                  child: LiveIndicator(),
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Metadata Header
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            Text(t['games']['name']?.toString().toUpperCase() ?? '', style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text(t['title'], style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: -0.5)),
                         ],
                       ),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: StitchTheme.primary.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: StitchTheme.primary.withOpacity(0.3)),
                         ),
                         child: Text(
                           t['tournament_type'].toString().toUpperCase(),
                           style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold, fontSize: 10),
                         ),
                       ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Slot Progress Bar
                  SlotProgressBar(joined: t['joined_slots'] ?? 0, total: t['total_slots'] ?? 0),
                  
                  const SizedBox(height: 24),

                  // Countdown or Start Time
                  if (status == 'upcoming' && t['start_time'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          const Text('TOURNAMENT STARTS IN', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 16),
                          TournamentCountdown(startTime: DateTime.parse(t['start_time'])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Info Grid
                  Row(
                    children: [
                      Expanded(
                        child: _ModernInfoCard(icon: Icons.payments_rounded, title: 'Entry Fee', value: '₹${t['entry_fee']}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModernInfoCard(icon: Icons.radar_rounded, title: 'Per Kill', value: '₹${t['per_kill_reward']}'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  
                  // Description
                  _SectionHeader(title: 'Overview'),
                  const SizedBox(height: 12),
                  Text(t['description'] ?? 'No description available.', style: const TextStyle(color: StitchTheme.textMuted, height: 1.6, fontSize: 14)),
                  
                  if (t['prize_description'] != null) ...[
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'Prize Pool'),
                    const SizedBox(height: 12),
                    Text(t['prize_description'], style: const TextStyle(color: StitchTheme.textMuted, height: 1.6, fontSize: 14)),
                  ],

                  if (t['rank_prizes'] != null) ...[
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'Prize Distribution'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: StitchTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: (t['rank_prizes'] as Map<String, dynamic>).entries.map((e) {
                          final rankNum = int.tryParse(e.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          final isTop3 = rankNum <= 3 && rankNum > 0;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isTop3 ? StitchTheme.primary.withOpacity(0.05) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isTop3 ? Icons.workspace_premium_rounded : Icons.military_tech_rounded, 
                                      color: isTop3 ? (rankNum == 1 ? Colors.amber : StitchTheme.primary) : StitchTheme.textMuted, 
                                      size: 20
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      e.key.startsWith('Rank') ? e.key : 'Rank ${e.key}', 
                                      style: TextStyle(
                                        color: isTop3 ? StitchTheme.textMain : StitchTheme.textMuted, 
                                        fontWeight: isTop3 ? FontWeight.w900 : FontWeight.normal, 
                                        fontSize: 14
                                      )
                                    ),
                                  ],
                                ),
                                Text('₹${e.value}', style: TextStyle(color: StitchTheme.success, fontWeight: FontWeight.w900, fontSize: 16)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  _SectionHeader(title: 'Participants'),
                  const SizedBox(height: 12),
                  if (_participants.isEmpty)
                    const StitchCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No entries yet. Be the first!', style: TextStyle(color: StitchTheme.textMuted)))))
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: StitchTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: _participants.map((p) {
                          final user = p['users'];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: StitchTheme.primary.withOpacity(0.1),
                              child: Text(user['name']?[0] ?? '?', style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(user['name'] ?? 'Player', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('@${user['username'] ?? 'user'}', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11)),
                            trailing: const Icon(Icons.check_circle_rounded, color: StitchTheme.success, size: 16),
                          );
                        }).toList(),
                      ),
                    ),

                  if (_hasJoined && status == 'ongoing') ...[
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'Match Credentials'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: StitchTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: StitchTheme.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          _ModernCopyRow(label: 'Room ID', value: t['room_id'] ?? 'WAITING...'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Colors.white10),
                          ),
                          _ModernCopyRow(label: 'Password', value: t['room_password'] ?? 'WAITING...'),
                        ]
                      )
                    )
                  ],

                  if (status == 'completed') ...[
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'Final Statistics'),
                    const SizedBox(height: 12),
                    if (_hasJoined && _joinedTeamData != null) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: StitchTheme.primaryGradient.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: StitchTheme.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ModernStatTile(label: 'RANK', value: '#${_joinedTeamData!['rank'] ?? '-'}'),
                            _ModernStatTile(label: 'KILLS', value: '${_joinedTeamData!['kills'] ?? '0'}'),
                            _ModernStatTile(label: 'PRIZE', value: '₹${_joinedTeamData!['total_prize'] ?? '0'}', highlight: true),
                          ],
                        ),
                      ),
                    ] else ...[
                      const StitchCard(child: Center(child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('Tournament has ended.', style: TextStyle(color: StitchTheme.textMuted)),
                      ))),
                    ],
                  ],
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildActionBtn(),
    );
  }

  Widget? _buildActionBtn() {
    final status = _tournament!['status'];
    final isFull = _tournament!['joined_slots'] >= _tournament!['total_slots'];

    if (_hasJoined) {
      if (status == 'upcoming') {
        return const StitchButton(text: 'Joined Successfully', isSecondary: true);
      }
      return null;
    }

    if (status == 'upcoming') {
      if (isFull) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: StitchButton(text: 'Full', isSecondary: true),
        );
      }
      return Container(
        width: 250,
        height: 80,
        padding: const EdgeInsets.only(bottom: 20),
        child: StitchButton(
          text: 'Join (₹${_tournament!['entry_fee']})',
          isLoading: _isJoining,
          onPressed: _navigateToJoin,
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(), 
      style: const TextStyle(
        fontSize: 14, 
        fontWeight: FontWeight.w900, 
        color: StitchTheme.textMain, 
        letterSpacing: 2
      )
    );
  }
}

class _ModernInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _ModernInfoCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: StitchTheme.primary, size: 20),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: StitchTheme.textMuted.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

class _ModernCopyRow extends StatelessWidget {
  final String label;
  final String value;
  const _ModernCopyRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: StitchTheme.textMuted.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
          ],
        ),
        IconButton(
          onPressed: () {
            // Copy logic
          }, 
          icon: const Icon(Icons.copy_all_rounded, size: 22, color: StitchTheme.primary)
        )
      ],
    );
  }
}

class _ModernStatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _ModernStatTile({required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: StitchTheme.textMuted.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(
          value, 
          style: TextStyle(
            color: highlight ? StitchTheme.success : StitchTheme.textMain, 
            fontWeight: FontWeight.w900, 
            fontSize: 24,
            fontFamily: 'monospace',
          )
        ),
      ],
    );
  }
}

