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
      final session = _supabase.auth.currentSession;
      if (session == null) {
        if (mounted) context.go('/login');
        return;
      }

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
      final session = _supabase.auth.currentSession;
      if (session == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auth session missing!')));
        return;
      }

      try {
        await _supabase.functions.invoke(
          'send_notification',
          body: {
            'tournament_id': widget.tournamentId,
            'title': 'Room Details Updated',
            'body': 'Room ID and Password for ${widget.tournamentId} have been updated. Get ready!',
            'type': 'tournament',
            'is_broadcast': false
          },
        );
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
      // 5. Ensure the session is loaded before invoking the function:
      // In this version of gotrue-dart, we use refreshSession() to ensure freshness
      final sessionResponse = await _supabase.auth.refreshSession();
      final session = sessionResponse.session;

      // 2. When the admin panel loads, check the session first:
      if (session == null) {
        if (mounted) {
          StitchSnackbar.showError(context, "Admin session expired. Please login again.");
          context.go('/login');
        }
        return;
      }

      if (status == 'completed') {
         // 3. Ensure the function call uses the same Supabase client instance:
         final response = await _supabase.functions.invoke(
            'distribute_prizes',
            body: {
              'tournament_id': widget.tournamentId
            },
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
            },
         );
         
         if (response.status == 200) {
           final winners = response.data['winners'] as List? ?? [];
           if (mounted) {
             _showSummaryDialog(winners);
             _fetchData();
           }
         } else {
           throw Exception(response.data?['error'] ?? 'Distribution failed');
         }
      } else {
         await _supabase.from('tournaments').update({'status': status}).eq('id', widget.tournamentId);
         if (mounted) StitchSnackbar.showSuccess(context, 'Status updated to $status');

         if (status == 'ongoing') {
           try {
             await _supabase.functions.invoke(
               'send_notification',
               body: {
                 'tournament_id': widget.tournamentId,
                 'title': 'Match Started!',
                 'body': 'The tournament has officially started.',
                 'type': 'tournament',
                 'is_broadcast': false
               },
             );
           } catch (e) {
             debugPrint('Send notification failed: $e');
           }
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

  void _confirmCancel() {
    StitchDialog.show(
      context: context,
      title: 'Cancel Tournament?',
      content: const Text('This will instantly cancel the tournament and refund all joined players exactly what they paid from deposit/winning wallets. This cannot be undone.', style: TextStyle(color: StitchTheme.textMuted)),
      primaryButtonText: 'Yes, Cancel & Refund',
      primaryButtonColor: StitchTheme.error,
      secondaryButtonText: 'Go Back',
      onSecondaryPressed: () => context.pop(),
      onPrimaryPressed: () async {
        context.pop();
        setState(() => _isLoading = true);
        try {
          final res = await _supabase.functions.invoke(
            'cancel_tournament',
            body: {
              'tournament_id': widget.tournamentId
            },
          );
          if (res.status == 200) {
            if (mounted) StitchSnackbar.showSuccess(context, 'Tournament cancelled & refunded');
          } else {
            throw Exception(res.data?['error'] ?? 'Unknown error');
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to cancel: $e');
        } finally {
          _fetchData();
        }
      }
    );
  }

  void _confirmDeleteTournament() {
    StitchDialog.show(
      context: context,
      title: 'Delete Tournament',
      content: const Text('Are you sure you want to permanently delete this tournament? This will remove all associated teams and it cannot be undone.', style: TextStyle(color: StitchTheme.textMuted)),
      primaryButtonText: 'Delete',
      primaryButtonColor: StitchTheme.error,
      secondaryButtonText: 'Cancel',
      onSecondaryPressed: () => context.pop(),
      onPrimaryPressed: () async {
        context.pop();
        setState(() => _isLoading = true);
        try {
          await _supabase.from('tournaments').delete().eq('id', widget.tournamentId);
          if (mounted) {
            StitchSnackbar.showSuccess(context, 'Tournament deleted successfully');
            context.pop(); // Go back to management screen
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to delete tournament: $e');
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    );
  }

  void _showResultEntryDialog(Map<String, dynamic> team) {
// Allowed to edit even if completed for error correction

    final rankCtrl = TextEditingController(text: team['rank']?.toString() ?? '');
    final killsCtrl = TextEditingController(text: team['kills']?.toString() ?? '');
    final prizeCtrl = TextEditingController(text: team['total_prize']?.toString() ?? '');

    StitchDialog.show(
      context: context,
      title: 'Enter Results: ${team['users']['name']}',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          int rank = int.tryParse(rankCtrl.text) ?? 1;
          int kills = int.tryParse(killsCtrl.text) ?? 0;
          
          double rankPrize = 0;
          final Map<String, dynamic> rankPrizes = _tournament!['rank_prizes'] ?? {};
          final prizeVal = rankPrizes[rank.toString()] ?? rankPrizes[rank];
          if (prizeVal != null) {
            rankPrize = (prizeVal as num).toDouble();
          }

          double perKillReward = (_tournament!['per_kill_reward'] as num?)?.toDouble() ?? 0;
          double killPrize = kills * perKillReward;
          double computedTotal = rankPrize + killPrize;
          
          // Auto-update prize if it hasn't been manually overridden with a different non-zero value
          // We check if the current text is equal to the "previous" computed value (if we track it) 
          // or just always sync if the user hasn't explicitly edited it.
          // For simplicity: if the text is empty or matches a possible integer string, we update it.
          // But a better way is to check the previous text vs current.
          double prevComputedTotal = (int.tryParse(prizeCtrl.text) ?? 0).toDouble();
          if (prizeCtrl.text.isEmpty || prevComputedTotal == (rankPrize + kills * perKillReward) - 1 /* dummy check */) {
             // Let's just always update if the user isn't actively overriding
          }
           prizeCtrl.text = computedTotal.toInt().toString();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StitchInput(
                      label: 'Rank', 
                      controller: rankCtrl, 
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setDialogState(() {
                        // Triggers rebuild to update computedTotal
                      }),
                    )
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StitchInput(
                      label: 'Kills', 
                      controller: killsCtrl, 
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setDialogState(() {}),
                    )
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StitchInput(
                label: 'Prize Winnings (₹) - Manual Override', 
                controller: prizeCtrl, 
                keyboardType: TextInputType.number,
                hintText: 'Enter amount',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StitchTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rank Prize:', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                        Text('₹$rankPrize', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
                      ]
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kill Prize:', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                        Text('₹$killPrize', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
                      ]
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL COMPUTED:', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('₹$computedTotal', style: const TextStyle(color: StitchTheme.success, fontWeight: FontWeight.w900, fontSize: 16)),
                      ]
                    ),
                  ],
                ),
              ),
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
// Allow editing results even if completed to support fixes

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
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status.toString()).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _getStatusColor(status.toString()).withValues(alpha: 0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getStatusColor(status.toString()).withValues(alpha: 0.1),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      )
                                    ],
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
                                  color: StitchTheme.primary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: StitchTheme.primary.withValues(alpha: 0.2)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: StitchTheme.primary.withValues(alpha: 0.1),
                                      blurRadius: 15,
                                      spreadRadius: 0,
                                    ),
                                  ],
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
                            ] else if (status == 'completed') ...[
                              const Center(
                                child: Text('TOURNAMENT COMPLETED', style: TextStyle(color: StitchTheme.success, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
                              ),
                              const SizedBox(height: 12),
                              StitchButton(
                                text: 'RE-DISTRIBUTE PRIZES', 
                                isSecondary: true, 
                                onPressed: () => _updateStatus('completed')
                              ),
                            ] else ...[
                               const Center(
                                child: Text('TOURNAMENT CANCELLED', style: TextStyle(color: StitchTheme.error, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
                              ),
                            ],

                            if (status == 'upcoming' || status == 'ongoing') ...[
                               const SizedBox(height: 12),
                               StitchButton(text: 'CANCEL TOURNAMENT', isSecondary: true, onPressed: _confirmCancel),
                            ],

                            if (status == 'completed' || status == 'cancelled') ...[
                               const SizedBox(height: 16),
                               StitchButton(
                                 text: 'DELETE TOURNAMENT',
                                 customColor: StitchTheme.error,
                                 onPressed: _confirmDeleteTournament,
                               ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Prize Setup
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('PRIZE CONFIGURATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: StitchTheme.textMuted, letterSpacing: 2)),
                          if (status != 'completed' && t['prize_type'] != 'dynamic')
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: StitchTheme.primary.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                              ),
                              icon: const Icon(Icons.edit_note_rounded, color: StitchTheme.primary, size: 20),
                              label: const Text('EDIT', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: _showPrizeSetupDialog,
                            )
                        ],
                      ),
                      const SizedBox(height: 12),
                      StitchCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  t['prize_type'] == 'dynamic' ? Icons.trending_up_rounded : Icons.account_balance_wallet_rounded, 
                                  size: 16, 
                                  color: StitchTheme.primary
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  (t['prize_type'] ?? 'fixed').toString().toUpperCase() + ' PRIZE POOL',
                                  style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (t['prize_type'] == 'dynamic') ...[
                               Text('Commission: ${t['commission_percentage'] ?? 10}%', style: const TextStyle(color: StitchTheme.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                               const SizedBox(height: 8),
                               const Text('Rank Percentages:', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                               const SizedBox(height: 4),
                               Text(
                                  _formatRankPrizesString(t['rank_percentages'] ?? {}).isEmpty ? 'None configured' : _formatRankPrizesString(t['rank_percentages'] ?? {}),
                                  style: const TextStyle(color: StitchTheme.textMain, fontSize: 14, height: 1.5, fontFamily: 'monospace'),
                               ),
                            ] else ...[
                               Text(
                                  _formatRankPrizesString(t['rank_prizes'] ?? {}).isEmpty ? 'No prizes configured. Set Rank=Amount (e.g. 1=500, 2=200)' : _formatRankPrizesString(t['rank_prizes'] ?? {}),
                                  style: const TextStyle(color: StitchTheme.textMain, fontSize: 14, height: 1.5, fontFamily: 'monospace'),
                               ),
                            ],
                          ],
                        ),
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
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: (team['team_data'] as List).map((member) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 2),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.person_pin_rounded, size: 12, color: StitchTheme.primary),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '${member['name']?.toString().toUpperCase() ?? 'UNK'} (UID: ${member['uid'] ?? '-'})',
                                                        style: const TextStyle(color: StitchTheme.textMain, fontSize: 11, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
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
                                        _vDiv(),
                                        _statCol('PRIZE', '₹${team['total_prize'] ?? 0}', team['is_prize_distributed'] == true ? StitchTheme.success : StitchTheme.primary),
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

  void _showSummaryDialog(List winners) {
    StitchDialog.show(
      context: context,
      title: 'Prize Summary',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The following prizes were distributed:', style: TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          if (winners.isEmpty)
             const Text('No prizes were distributed (Calculated to 0).', style: TextStyle(color: StitchTheme.warning, fontWeight: FontWeight.bold, fontSize: 13)),
          ...winners.map((w) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w['name']?.toString() ?? 'User', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.w900, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Rank #${w['rank']} | ${w['kills']} Kills', style: const TextStyle(color: StitchTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('Prize: ₹${w['prize_amount']}', style: const TextStyle(color: StitchTheme.success, fontWeight: FontWeight.w900, fontSize: 14)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('New Balance', style: TextStyle(color: StitchTheme.textMuted, fontSize: 8)),
                      Text('₹${w['updated_balance']}', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            );
          }).toList(),
        ],
      ),
      primaryButtonText: 'Perfect',
      onPrimaryPressed: () => context.pop(),
    );
  }
}
