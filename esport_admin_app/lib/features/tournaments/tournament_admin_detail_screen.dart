import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class TournamentAdminDetailScreen extends StatefulWidget {
  final String tournamentId;
  const TournamentAdminDetailScreen({Key? key, required this.tournamentId}) : super(key: key);

  @override
  State<TournamentAdminDetailScreen> createState() => _TournamentAdminDetailScreenState();
}

class _TournamentAdminDetailScreenState extends State<TournamentAdminDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _tournament;
  List<Map<String, dynamic>> _teams = [];

  final _roomIdCtrl = TextEditingController();
  final _roomPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final futures = await Future.wait([
        _supabase.from('tournaments').select('*, games(name)').eq('id', widget.tournamentId).single(),
        _supabase.from('joined_teams').select('*, users(name, username)').eq('tournament_id', widget.tournamentId).order('created_at'),
      ]);

      if (mounted) {
        setState(() {
          _tournament = futures[0] as Map<String, dynamic>;
          _teams = List<Map<String, dynamic>>.from(futures[1] as List);
          _roomIdCtrl.text = _tournament?['room_id'] ?? '';
          _roomPassCtrl.text = _tournament?['room_password'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         StitchSnackbar.showError(context, 'Failed to fetch tournament data.');
      }
    }
  }

  Future<void> _updateRoomDetails() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('tournaments').update({
        'room_id': _roomIdCtrl.text.trim(),
        'room_password': _roomPassCtrl.text.trim()
      }).eq('id', widget.tournamentId);
      
      // Notify all joined users via Edge Func
      try {
        await _supabase.functions.invoke('send_notification', body: {
          'tournament_id': widget.tournamentId,
          'title': 'Room Details Updated',
          'body': 'Room ID and Password for ${widget.tournamentId} have been updated. Get ready!',
          'type': 'tournament',
          'is_broadcast': false
        });
      } catch (e) {
        debugPrint('Failed to send push: $e');
      }

      if (mounted) StitchSnackbar.showSuccess(context, 'Room details updated');
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to update room');
    } finally {
      _fetchData();
    }
  }

  Future<void> _updateStatus(String status) async {
    if (status == 'completed' && !_allResultsEntered()) {
      StitchSnackbar.showError(context, 'Please enter Rank and Kills for all teams before completing.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (status == 'completed') {
         // Use Secure Edge Function to distribute prizes and mark complete
         final response = await _supabase.functions.invoke(
            'distribute_prizes',
            body: {'tournament_id': widget.tournamentId}
         );
         
         if (response.status == 200) {
           if (mounted) StitchSnackbar.showSuccess(context, 'Tournament Completed & Prizes Distributed!');
           
           try {
             await _supabase.functions.invoke('send_notification', body: {
               'tournament_id': widget.tournamentId,
               'title': 'Results Announced',
               'body': 'Tournament completed. Winnings have been transferred!',
               'type': 'tournament',
               'is_broadcast': false
             });
           } catch (_) {}
         } else {
           throw Exception(response.data?['error'] ?? 'Distribution failed');
         }
      } else {
         await _supabase.from('tournaments').update({'status': status}).eq('id', widget.tournamentId);
         if (mounted) StitchSnackbar.showSuccess(context, 'Status updated to $status');

         if (status == 'ongoing') {
           try {
             await _supabase.functions.invoke('send_notification', body: {
               'tournament_id': widget.tournamentId,
               'title': 'Match Started!',
               'body': 'The tournament has officially started.',
               'type': 'tournament',
               'is_broadcast': false
             });
           } catch (_) {}
         }
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString());
    } finally {
      _fetchData();
    }
  }

  bool _allResultsEntered() {
    if (_teams.isEmpty) return false;
    for (var t in _teams) {
      if (t['rank'] == null || t['kills'] == null) return false;
    }
    return true;
  }

  void _showResultEntryDialog(Map<String, dynamic> team) {
    if (_tournament!['status'] == 'completed') return; // Readonly if completed

    final rankCtrl = TextEditingController(text: team['rank']?.toString() ?? '');
    final killsCtrl = TextEditingController(text: team['kills']?.toString() ?? '');
    final prizeCtrl = TextEditingController(text: team['total_prize']?.toString() ?? '');

    StitchDialog.show(
      context: context,
      title: 'Enter Results for ${team['users']['name']}',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          int rank = int.tryParse(rankCtrl.text) ?? 0;
          int kills = int.tryParse(killsCtrl.text) ?? 0;
          
          double rankPrize = 0;
          final Map<String, dynamic> rankPrizes = _tournament!['rank_prizes'] ?? {};
          if (rankPrizes.containsKey(rank.toString())) {
             rankPrize = (rankPrizes[rank.toString()] as num).toDouble();
          }

          double perKillReward = (_tournament!['per_kill_reward'] as num?)?.toDouble() ?? 0;
          double killPrize = kills * perKillReward;
          double computedTotal = rankPrize + killPrize;
          
          // Auto-update prize text if it's empty OR if it matches previous computation
          // This gives standard calculation while still allowing manual override.
          if (prizeCtrl.text.isEmpty) {
             prizeCtrl.text = computedTotal.toInt().toString();
          }

          void updateValues() {
            setDialogState(() {
               computedTotal = rankPrize + killPrize;
               prizeCtrl.text = computedTotal.toInt().toString();
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StitchInput(
                label: 'Rank', 
                controller: rankCtrl, 
                keyboardType: TextInputType.number,
                onChanged: (v) => updateValues(),
              ),
              const SizedBox(height: 12),
              StitchInput(
                label: 'Total Kills', 
                controller: killsCtrl, 
                keyboardType: TextInputType.number,
                onChanged: (v) => updateValues(),
              ),
              const SizedBox(height: 12),
              StitchInput(
                label: 'Prize Winnings (₹)', 
                controller: prizeCtrl, 
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StitchTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Computed Kill Prize:', style: TextStyle(color: StitchTheme.textMuted)),
                        Text('₹$killPrize', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
                      ]
                    ),
                    const SizedBox(height: 4),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text('Computed Rank Prize:', style: TextStyle(color: StitchTheme.textMuted)),
                         Text('₹$rankPrize', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
                       ]
                    ),
                  ],
                ),
              )
            ],
          );
        }
      ),
      primaryButtonText: 'Save',
      onPrimaryPressed: () async {
        if (rankCtrl.text.isEmpty || killsCtrl.text.isEmpty) {
          StitchSnackbar.showError(context, 'Both fields are required');
          return;
        }
        
        try {
          int rank = int.parse(rankCtrl.text);
          int kills = int.parse(killsCtrl.text);
          double userPrize = prizeCtrl.text.isEmpty ? 0 : double.parse(prizeCtrl.text);

          await _supabase.from('joined_teams').update({
            'rank': rank,
            'kills': kills,
            'total_prize': userPrize,
          }).eq('id', team['id']);
          
          if (mounted) {
             context.pop();
             StitchSnackbar.showSuccess(context, 'Results saved');
             _fetchData();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to save');
        }
      }
    );
  }

  void _showPrizeSetupDialog() {
    if (_tournament!['status'] == 'completed') return;

    final Map<String, dynamic> currentPrizes = _tournament!['rank_prizes'] ?? {};
    final String initialText = _formatRankPrizesString(currentPrizes);
    final prizesCtrl = TextEditingController(text: initialText);

    StitchDialog.show(
      context: context,
      title: 'Set Prize Pool',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Format: Rank=Amount, comma separated.\nExample: 1=500, 2=200, 3=100', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          StitchInput(label: 'Prizes Map', controller: prizesCtrl, maxLines: 3),
        ],
      ),
      primaryButtonText: 'Save',
      onPrimaryPressed: () async {
        try {
          final Map<String, dynamic> prizeMap = {};
          final pairs = prizesCtrl.text.split(',');
          for (var p in pairs) {
            final parts = p.split('=');
            if (parts.length == 2) {
              final rank = parts[0].trim();
              final amount = double.parse(parts[1].trim());
              prizeMap[rank] = amount;
            }
          }

          await _supabase.from('tournaments').update({'rank_prizes': prizeMap}).eq('id', widget.tournamentId);
          if (mounted) {
             context.pop();
             StitchSnackbar.showSuccess(context, 'Prize pool updated');
             _fetchData();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Invalid format. Use Rank=Amount');
        }
      }
    );
  }

  String _formatRankPrizesString(Map<String, dynamic> prizes) {
    if (prizes.isEmpty) return '';
    return prizes.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());
    if (_tournament == null) return const Scaffold(body: StitchError(message: 'Not found'));

    final t = _tournament!;
    final status = t['status'];

    return Scaffold(
      appBar: AppBar(
        title: Text(t['title']),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth > 800 ? 800 : constraints.maxWidth;
          final ScrollController scrollController = ScrollController();
          
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Scrollbar(
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card with Main Info
                      StitchCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CURRENT STATUS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                    const SizedBox(height: 8),
                                    StitchBadge(
                                      text: status.toString().toUpperCase(),
                                      color: _getStatusColor(status.toString()),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.surfaceHighlight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    status == 'ongoing' ? Icons.play_circle_filled_rounded : 
                                    status == 'upcoming' ? Icons.event_rounded : Icons.check_circle_rounded,
                                    color: _getStatusColor(status.toString()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Slot Progress Bar
                            SlotProgressBar(joined: t['joined_slots'] ?? 0, total: t['total_slots'] ?? 0),
                            
                            const SizedBox(height: 24),
                            
                            // Countdown for Admin
                            if (status == 'upcoming' && t['start_time'] != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Column(
                                  children: [
                                    const Text('SCHEDULED START IN', style: TextStyle(color: StitchTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                    const SizedBox(height: 12),
                                    TournamentCountdown(startTime: DateTime.parse(t['start_time']).toLocal()),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            if (status == 'upcoming') ...[
                              StitchButton(text: 'START TOURNAMENT', onPressed: () => _updateStatus('ongoing')),
                            ] else if (status == 'ongoing') ...[
                              StitchButton(text: 'FINISH & CALCULATE PRIZES', onPressed: () => _updateStatus('completed')),
                            ] else ...[
                              const Center(
                                child: Text('TOURNAMENT ARCHIVED', style: TextStyle(color: StitchTheme.success, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
                              ),
                            ]
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Prize Setup
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('PRIZE CONFIGURATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: StitchTheme.textMuted, letterSpacing: 2)),
                          if (status != 'completed')
                            TextButton.icon(
                              icon: const Icon(Icons.edit_note_rounded, color: StitchTheme.primary, size: 20),
                              label: const Text('EDIT', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: _showPrizeSetupDialog,
                            )
                        ],
                      ),
                      const SizedBox(height: 12),
                      StitchCard(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _formatRankPrizesString(t['rank_prizes'] ?? {}).isEmpty ? 'No prizes configured. Set Rank=Amount (e.g. 1=500, 2=200)' : _formatRankPrizesString(t['rank_prizes'] ?? {}),
                          style: const TextStyle(color: StitchTheme.textMain, fontSize: 14, height: 1.5, fontFamily: 'monospace'),
                        )
                      ),

                      const SizedBox(height: 32),

                      // Room Setup
                      if (status != 'completed') ...[
                        const Text('MATCH CREDENTIALS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: StitchTheme.textMuted, letterSpacing: 2)),
                        const SizedBox(height: 12),
                        StitchCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              StitchInput(label: 'Room ID', controller: _roomIdCtrl, hintText: 'Enter Room/Lobby ID'),
                              const SizedBox(height: 16),
                              StitchInput(label: 'Room Password', controller: _roomPassCtrl, hintText: 'Enter Lobby Password'),
                              const SizedBox(height: 20),
                              StitchButton(text: 'UPDATE GAME ROOM', isSecondary: true, onPressed: _updateRoomDetails),
                            ],
                          )
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Participants / Results List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('PARTICIPANTS & SCORING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: StitchTheme.textMuted, letterSpacing: 2)),
                          if (_teams.isNotEmpty)
                            Text('${_teams.length} PLAYERS', style: const TextStyle(color: StitchTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_teams.isEmpty)
                        const StitchCard(child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text('NO PLAYERS JOINED YET', style: TextStyle(color: StitchTheme.textMuted, letterSpacing: 1, fontSize: 12)))))
                      else
                        ..._teams.map((team) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: StitchCard(
                              onTap: () => _showResultEntryDialog(team),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(team['users']['name'], style: const TextStyle(fontWeight: FontWeight.w900, color: StitchTheme.textMain, fontSize: 14)),
                                        const SizedBox(height: 4),
                                        if (team['team_data'] != null && (team['team_data'] as List).isNotEmpty)
                                          Text('SQUAD: ${(team['team_data'] as List).map((e) => e['name']).join(', ').toUpperCase()}', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10, letterSpacing: 0.5)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        _statCol('RANK', team['rank']?.toString() ?? '-', StitchTheme.primary),
                                        _vDiv(),
                                        _statCol('KILLS', team['kills']?.toString() ?? '-', StitchTheme.textMain),
                                        if (status == 'completed') ...[
                                          _vDiv(),
                                          _statCol('PRIZE', '₹${team['total_prize'] ?? 0}', StitchTheme.success),
                                        ]
                                      ],
                                    )
                                  )
                                ],
                              )
                            )
                          );
                        }).toList(),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _vDiv() {
    return Container(width: 1, height: 20, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 16));
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming': return StitchTheme.secondary;
      case 'ongoing': return StitchTheme.warning;
      case 'completed': return StitchTheme.success;
      default: return StitchTheme.textMuted;
    }
  }
}
