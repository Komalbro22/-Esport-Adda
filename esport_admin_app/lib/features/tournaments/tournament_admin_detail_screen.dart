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
      
      // Optionally notify all joined users here via Edge Func
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
         } else {
           throw Exception(response.data?['error'] ?? 'Distribution failed');
         }
      } else {
         await _supabase.from('tournaments').update({'status': status}).eq('id', widget.tournamentId);
         if (mounted) StitchSnackbar.showSuccess(context, 'Status updated to $status');
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
          double totalPrize = rankPrize + killPrize;

          void updateValues() {
            setDialogState(() {});
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
                        const Text('Kill Prize:', style: TextStyle(color: StitchTheme.textMuted)),
                        Text('₹$killPrize', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
                      ]
                    ),
                    const SizedBox(height: 4),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text('Rank Prize:', style: TextStyle(color: StitchTheme.textMuted)),
                         Text('₹$rankPrize', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold)),
                       ]
                    ),
                    const Divider(color: StitchTheme.surfaceHighlight),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text('Total Prize:', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
                         Text('₹$totalPrize', style: const TextStyle(color: StitchTheme.success, fontWeight: FontWeight.bold, fontSize: 18)),
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
          
          double rankPrize = 0;
          final Map<String, dynamic> rankPrizes = _tournament!['rank_prizes'] ?? {};
          if (rankPrizes.containsKey(rank.toString())) {
             rankPrize = (rankPrizes[rank.toString()] as num).toDouble();
          }

          double perKillReward = (_tournament!['per_kill_reward'] as num?)?.toDouble() ?? 0;
          double killPrize = kills * perKillReward;
          double totalPrize = rankPrize + killPrize;

          await _supabase.from('joined_teams').update({
            'rank': rank,
            'kills': kills,
            'total_prize': totalPrize,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and actions
            StitchCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Status:', style: TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
                      StitchBadge(
                        text: status.toString(),
                        color: StitchTheme.primary,
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (status == 'upcoming') ...[
                    StitchButton(text: 'Start Tournament (Mark Ongoing)', onPressed: () => _updateStatus('ongoing')),
                  ] else if (status == 'ongoing') ...[
                    StitchButton(text: 'Finish & Distribute Prizes', onPressed: () => _updateStatus('completed')),
                  ] else ...[
                    const Text('Tournament is completed. Prizes have been distributed.', style: TextStyle(color: StitchTheme.success, fontWeight: FontWeight.bold)),
                  ]
                ],
              )
            ),
            
            const SizedBox(height: 24),
            
            // Prize Setup
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Prize Pool Config', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                if (status != 'completed')
                  TextButton.icon(
                    icon: const Icon(Icons.edit, color: StitchTheme.primary, size: 16),
                    label: const Text('Edit', style: TextStyle(color: StitchTheme.primary)),
                    onPressed: _showPrizeSetupDialog,
                  )
              ],
            ),
            const SizedBox(height: 8),
            StitchCard(
              child: Text(
                _formatRankPrizesString(t['rank_prizes'] ?? {}).isEmpty ? 'No rank prizes configured. Set them before finishing.' : _formatRankPrizesString(t['rank_prizes'] ?? {}),
                style: const TextStyle(color: StitchTheme.textMain),
              )
            ),

            const SizedBox(height: 24),

            // Room Setup
            if (status != 'completed') ...[
              const Text('Room Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
              const SizedBox(height: 8),
              StitchCard(
                child: Column(
                  children: [
                    StitchInput(label: 'Room ID', controller: _roomIdCtrl),
                    const SizedBox(height: 12),
                    StitchInput(label: 'Room Password', controller: _roomPassCtrl),
                    const SizedBox(height: 16),
                    StitchButton(text: 'Update Room Detials', isSecondary: true, onPressed: _updateRoomDetails),
                  ],
                )
              ),
              const SizedBox(height: 24),
            ],

            // Participants / Results List
            const Text('Participants & Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
            const SizedBox(height: 8),
            if (_teams.isEmpty)
              const StitchCard(child: Text('No participants yet.', style: TextStyle(color: StitchTheme.textMuted)))
            else
              ..._teams.map((team) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: StitchCard(
                    onTap: () => _showResultEntryDialog(team),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(team['users']['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain, fontSize: 16)),
                              if (team['team_data'] != null && (team['team_data'] as List).isNotEmpty)
                                Text('Squad: ${(team['team_data'] as List).map((e) => e['name']).join(', ')}', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  const Text('Rank', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
                                  Text(team['rank']?.toString() ?? '-', style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(width: 16),
                               Column(
                                children: [
                                  const Text('Kills', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
                                  Text(team['kills']?.toString() ?? '-', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              if (status == 'completed') ...[
                                const SizedBox(width: 16),
                                Column(
                                  children: [
                                    const Text('Prize', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
                                    Text('₹${team['total_prize'] ?? 0}', style: const TextStyle(color: StitchTheme.success, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ]
                            ],
                          )
                        )
                      ],
                    )
                  )
                );
              }).toList()
          ],
        ),
      ),
    );
  }
}
