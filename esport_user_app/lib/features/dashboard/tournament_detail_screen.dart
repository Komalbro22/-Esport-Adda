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

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final futures = await Future.wait([
        _supabase.from('tournaments').select('*, games(name)').eq('id', widget.tournamentId).single(),
        _supabase.from('joined_teams').select('*').eq('tournament_id', widget.tournamentId).eq('user_id', user.id).maybeSingle(),
      ]);

      if (mounted) {
        setState(() {
          _tournament = futures[0] as Map<String, dynamic>;
          _joinedTeamData = futures[1] as Map<String, dynamic>?;
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
      appBar: AppBar(
        title: Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Section
            if (t['banner_url'] != null && t['banner_url'].toString().isNotEmpty)
              Stack(
                children: [
                  Image.network(
                    t['banner_url'], 
                    height: 250, 
                    width: double.infinity, 
                    fit: BoxFit.cover, 
                    errorBuilder: (c,e,s) => Container(height: 200, color: StitchTheme.surfaceHighlight, child: const Icon(Icons.image_not_supported, color: StitchTheme.textMuted))
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            StitchTheme.background.withOpacity(0.8),
                            StitchTheme.background,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              const SizedBox(height: 20),

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
                            Text(t['games']['name'] ?? '', style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(t['title'], style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 22)),
                         ],
                       ),
                       StitchBadge(
                         text: t['tournament_type'].toString(),
                         color: StitchTheme.primary,
                       ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Info Grid
                  Row(
                    children: [
                      Expanded(
                        child: StitchCard(
                          padding: const EdgeInsets.all(12),
                          child: _InfoTile(icon: Icons.payments, title: 'Entry', value: '₹${t['entry_fee']}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StitchCard(
                          padding: const EdgeInsets.all(12),
                          child: _InfoTile(icon: Icons.track_changes, title: 'Per Kill', value: '₹${t['per_kill_reward']}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StitchCard(
                          padding: const EdgeInsets.all(12),
                          child: _InfoTile(icon: Icons.groups, title: 'Slots', value: '${t['joined_slots']}/${t['total_slots']}'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  StitchCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: StitchTheme.accent, size: 20),
                        const SizedBox(width: 12),
                        const Text('Starts on:', style: TextStyle(color: StitchTheme.textMuted, fontSize: 14)),
                        const Spacer(),
                        Text(
                          t['start_time'] != null 
                            ? DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.parse(t['start_time']).toLocal()) 
                            : 'TBA',
                          style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14)
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  // Description
                  _SectionHeader(title: 'Overview'),
                  const SizedBox(height: 12),
                  Text(t['description'] ?? 'No description available for this tournament.', style: const TextStyle(color: StitchTheme.textMuted, height: 1.6, fontSize: 14)),
                  
                  if (t['prize_description'] != null) ...[
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'Prize Details'),
                    const SizedBox(height: 12),
                    Text(t['prize_description'], style: const TextStyle(color: StitchTheme.textMuted, height: 1.6, fontSize: 14)),
                  ],

                  if (t['rank_prizes'] != null) ...[
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'Prize Distribution'),
                    const SizedBox(height: 12),
                    StitchCard(
                      child: Column(
                        children: (t['rank_prizes'] as Map<String, dynamic>).entries.map((e) {
                          final rankNum = int.tryParse(e.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          final isTop3 = rankNum <= 3 && rankNum > 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isTop3 ? Icons.workspace_premium : Icons.stars_rounded, 
                                      color: isTop3 ? StitchTheme.warning : StitchTheme.textMuted.withOpacity(0.5), 
                                      size: 18
                                    ),
                                    const SizedBox(width: 10),
                                    Text(e.key.startsWith('Rank') ? e.key : 'Rank ${e.key}', style: TextStyle(color: isTop3 ? StitchTheme.textMain : StitchTheme.textMuted, fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                                  ],
                                ),
                                Text('₹${e.value}', style: TextStyle(color: StitchTheme.success, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  if (_hasJoined && status == 'ongoing') ...[
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'Room Access'),
                    const SizedBox(height: 12),
                    StitchCard(
                      child: Column(
                        children: [
                          _CopyRow(label: 'Room ID', value: t['room_id'] ?? 'TBA'),
                          const Divider(color: StitchTheme.surfaceHighlight, height: 24),
                          _CopyRow(label: 'Password', value: t['room_password'] ?? 'TBA'),
                        ]
                      )
                    )
                  ],

                  if (status == 'completed') ...[
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'Your Match Stats'),
                    const SizedBox(height: 12),
                    if (_hasJoined && _joinedTeamData != null) ...[
                      StitchCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SmallStat(label: 'Rank', value: '#${_joinedTeamData!['rank'] ?? '-'}'),
                            _SmallStat(label: 'Kills', value: '${_joinedTeamData!['kills'] ?? '0'}'),
                            _SmallStat(label: 'Prize', value: '₹${_joinedTeamData!['total_prize'] ?? '0'}', isSuccess: true),
                          ],
                        ),
                      ),
                    ] else ...[
                      const StitchCard(child: Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('Tournament concluded.', style: TextStyle(color: StitchTheme.textMuted)),
                      ))),
                    ],
                  ],

                  const SizedBox(height: 120), // Bottom padding for button
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: StitchTheme.textMain, letterSpacing: 0.5));
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  const _CopyRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        IconButton(
          onPressed: () {
            // Copy logic
          }, 
          icon: const Icon(Icons.copy_rounded, size: 20, color: StitchTheme.primary)
        )
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isSuccess;
  const _SmallStat({required this.label, required this.value, this.isSuccess = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: isSuccess ? StitchTheme.success : StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 20)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: StitchTheme.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelectable;
  const _InfoRow({required this.label, required this.value, this.isSelectable = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        if (isSelectable)
          SelectableText(value, style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16))
        else
          Text(value, style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _ResultRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 15)),
          Text(value, style: TextStyle(color: valueColor ?? StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
