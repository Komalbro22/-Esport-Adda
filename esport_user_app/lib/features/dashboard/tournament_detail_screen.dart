import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

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

    return Scaffold(
      backgroundColor: const Color(0xFF13151D),
      appBar: AppBar(
        title: const Text('Tournament Details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
        backgroundColor: const Color(0xFF13151D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth > 700 ? 700 : constraints.maxWidth;
          
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C24),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Banner Image
                      Stack(
                        children: [
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(color: const Color(0xFF2A2D36)),
                            child: t['banner_url'] != null && t['banner_url'].toString().isNotEmpty
                                ? Image.network(t['banner_url'], fit: BoxFit.cover)
                                : const Icon(Icons.image_not_supported, color: Colors.white24, size: 40),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, const Color(0xFF1A1C24).withOpacity(0.9), const Color(0xFF1A1C24)],
                                  stops: const [0.5, 0.9, 1.0],
                                ),
                              ),
                            ),
                          ),
                          if (status == 'ongoing')
                            const Positioned(
                              top: 16,
                              left: 16,
                              child: Row(
                                children: [
                                  Icon(Icons.circle, color: Colors.redAccent, size: 10),
                                  SizedBox(width: 6),
                                  Text('Live Now', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Game Name Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t['games']['name']?.toString().toUpperCase() ?? 'GAME',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Title
                            Text(
                              t['title'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, height: 1.2),
                            ),
                            
                            const SizedBox(height: 24),

                            // Countdown Starts In
                            if (status == 'upcoming' && t['start_time'] != null) ...[
                              const Text('STARTS IN', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5)),
                              const SizedBox(height: 12),
                              _CustomCountdownBlock(startTime: DateTime.parse(t['start_time'])),
                              const SizedBox(height: 32),
                            ],

                            // Circular Info Pills (Mode, Entry Fee, Per Kill, Map)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _CircularPill(icon: Icons.groups_rounded, label: 'Type', value: t['tournament_type'].toString()),
                                  const SizedBox(width: 16),
                                  _CircularPill(icon: Icons.payments_rounded, label: 'Entry', value: '₹${t['entry_fee']}'),
                                  const SizedBox(width: 16),
                                  _CircularPill(icon: Icons.radar_rounded, label: 'Per Kill', value: '₹${t['per_kill_reward']}'),
                                  if (t['map_name'] != null) ...[
                                    const SizedBox(width: 16),
                                    _CircularPill(icon: Icons.map_rounded, label: 'Map', value: t['map_name'].toString()),
                                  ],
                                  if (t['mode'] != null) ...[
                                    const SizedBox(width: 16),
                                    _CircularPill(icon: Icons.sports_rounded, label: 'Mode', value: t['mode'].toString()),
                                  ],
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 24),
                    
                    // Prize Pool Section
                    if (t['rank_prizes'] != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          const Text('Prize Pool', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: (t['rank_prizes'] as Map<String, dynamic>).entries.map((e) {
                          final rankStr = e.key.replaceAll(RegExp(r'[^0-9]'), '');
                          final rankNum = int.tryParse(rankStr) ?? 0;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2D36),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    rankNum > 0 ? rankNum.toString() : '-',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    rankNum == 1 ? 'Winner' : rankNum == 2 ? 'Runner Up' : rankNum == 3 ? '3rd Place' : 'Rank $rankNum',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                                Text(
                                  '₹${e.value}',
                                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 14),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white10),
                    ],

                    const SizedBox(height: 24),
                    // Rules & Regulations
                    Row(
                      children: [
                        const Icon(Icons.description_rounded, color: Color(0xFF94A3B8), size: 18),
                        const SizedBox(width: 8),
                        const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(t['prize_description'] ?? 'No description available.', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.gavel_rounded, color: Color(0xFF94A3B8), size: 18),
                        const SizedBox(width: 8),
                        const Text('Rules & Regulations', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _RulesList(description: t['rules'] ?? 'No rules description available.'),
                    const SizedBox(height: 32),

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
                      const SizedBox(height: 16),
                      const Text('ROOM DETAILS', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13151D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            _ModernCopyRow(label: 'Room ID', value: t['room_id'] ?? 'WAITING...'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Colors.white10),
                            ),
                            _ModernCopyRow(label: 'Password', value: t['room_password'] ?? 'WAITING...'),
                          ]
                        )
                      ),
                      const SizedBox(height: 24),
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
                        const StitchCard(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('Tournament has ended.', style: TextStyle(color: StitchTheme.textMuted)),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
},
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
        return _actionContainer(
          text: 'JOINED SUCCESSFULLY',
          color: Colors.green,
          icon: Icons.check_circle_rounded,
        );
      }
      if (status == 'ongoing') {
        return _actionContainer(
          text: 'JOIN MATCH',
          color: Colors.blueAccent,
          icon: Icons.gamepad_rounded,
          onTap: () {
            StitchSnackbar.showSuccess(context, 'Launching Match...');
          }
        );
      }
      return null;
    }

    if (status == 'upcoming') {
      if (isFull) {
        return _actionContainer(
          text: 'TOURNAMENT FULL',
          color: const Color(0xFF2A2D36),
          textColor: Colors.white54,
        );
      }
      
      return GestureDetector(
        onTap: _isJoining ? null : _navigateToJoin,
        child: Container(
          width: 320,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: _isJoining 
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            : Row(
            children: [
              const Expanded(
                child: Center(
                  child: Text('Join Tournament', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('- ₹${_tournament!['entry_fee']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }
    
    return null;
  }

  Widget _actionContainer({required String text, required Color color, Color textColor = Colors.white, IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, color: textColor, size: 20),
            ]
          ],
        ),
      ),
    );
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
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F222A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: () {}, 
            icon: const Icon(Icons.copy_all_rounded, size: 20, color: Colors.blueAccent)
          ),
        )
      ],
    );
  }
}

class _RulesList extends StatelessWidget {
  final String description;
  const _RulesList({required this.description});
  @override
  Widget build(BuildContext context) {
    // Basic split for demo purposes, assume newlines separate rules
    final rules = description.split('\n').where((r) => r.trim().isNotEmpty).toList();
    if (rules.isEmpty) {
      rules.add('Room ID and Password will be shared 15 minutes before match start.');
      rules.add('Hackers/Emulator players will be immediately disqualified.');
      rules.add('Ensure your in-game name matches your registered name.');
      rules.add('Any kind of teaming up with opponent squads is strictly prohibited.');
    }

    return Column(
      children: rules.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.trim(),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.5),
                ),
              )
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CustomCountdownBlock extends StatefulWidget {
  final DateTime startTime;
  const _CustomCountdownBlock({required this.startTime});

  @override
  State<_CustomCountdownBlock> createState() => _CustomCountdownBlockState();
}

class _CustomCountdownBlockState extends State<_CustomCountdownBlock> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        final now = DateTime.now();
        if (widget.startTime.isAfter(now)) {
          _timeLeft = widget.startTime.difference(now);
        } else {
          _timeLeft = Duration.zero;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TimeCircle(value: _timeLeft.inDays, label: 'Days'),
        _TimeCircle(value: _timeLeft.inHours.remainder(24), label: 'Hours'),
        _TimeCircle(value: _timeLeft.inMinutes.remainder(60), label: 'Mins'),
        _TimeCircle(value: _timeLeft.inSeconds.remainder(60), label: 'Secs'),
      ],
    );
  }
}

class _TimeCircle extends StatelessWidget {
  final int value;
  final String label;
  const _TimeCircle({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF13151D),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          alignment: Alignment.center,
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CircularPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CircularPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF13151D),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Icon(icon, color: Colors.blueAccent, size: 24),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          value.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
        ),
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

