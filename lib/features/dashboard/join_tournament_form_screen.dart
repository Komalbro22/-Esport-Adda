import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class JoinTournamentFormScreen extends StatefulWidget {
  final String tournamentId;

  const JoinTournamentFormScreen({Key? key, required this.tournamentId}) : super(key: key);

  @override
  State<JoinTournamentFormScreen> createState() => _JoinTournamentFormScreenState();
}

class _JoinTournamentFormScreenState extends State<JoinTournamentFormScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _tournament;
  bool _isLoading = true;
  bool _isJoining = false;
  
  final TextEditingController _myNameController = TextEditingController();
  final TextEditingController _myUidController = TextEditingController();
  final List<TextEditingController> _teammateControllers = [];

  @override
  void initState() {
    super.initState();
    _fetchTournament();
  }

  Future<void> _fetchTournament() async {
    try {
      final data = await _supabase
          .from('tournaments')
          .select('*, games(name)')
          .eq('id', widget.tournamentId)
          .single();
      
      if (mounted) {
        setState(() {
          _tournament = data;
          final type = _tournament!['tournament_type'];
          int numTeammates = 0;
          if (type == 'duo') numTeammates = 1;
          if (type == 'squad') numTeammates = 3;
          
          for (int i = 0; i < numTeammates; i++) {
            _teammateControllers.add(TextEditingController());
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load tournament data');
      }
    }
  }

  Future<void> _handleJoin() async {
    if (_myNameController.text.trim().isEmpty || _myUidController.text.trim().isEmpty) {
      StitchSnackbar.showError(context, 'Please fill your in-game name and UID');
      return;
    }

    // Validate teammates
    for (var controller in _teammateControllers) {
      if (controller.text.trim().isEmpty) {
        StitchSnackbar.showError(context, 'Please fill all teammate names');
        return;
      }
    }

    setState(() => _isJoining = true);
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        if (mounted) StitchSnackbar.showError(context, 'Please login again.');
        return;
      }

      final List<Map<String, String>> teamData = [];
      // Add primary player
      teamData.add({
        'name': _myNameController.text.trim(),
        'uid': _myUidController.text.trim(),
        'is_leader': 'true'
      });
      // Add teammates
      for (var c in _teammateControllers) {
        teamData.add({'name': c.text.trim()});
      }

      print('DEBUG: Calling join_tournament with session valid: ${session.user.id}');

      final response = await _supabase.functions.invoke(
        'join_tournament',
        body: {
          'tournament_id': widget.tournamentId,
          'team_data': teamData
        },
      );
      
      print('DEBUG: Response status: ${response.status}');

      if (response.status == 200) {
        if (mounted) {
          StitchSnackbar.showSuccess(context, 'Successfully joined!');
          context.pop(true);
        }
      } else {
        final error = response.data?['error'] ?? 'Join failed (Status: ${response.status})';
        final details = response.data?['details'] ?? '';
        if (mounted) StitchSnackbar.showError(context, '$error ${details.isNotEmpty ? "($details)" : ""}');
      }
    } catch (e) {
      String msg = 'Error joining tournament';
      if (e is FunctionException) {
        msg = 'Function Error: ${e.status} - ${e.details}';
      } else if (e.toString().contains('authenticated')) {
        msg = 'Session expired. Please re-login.';
      } else {
        msg = e.toString();
      }
      if (mounted) StitchSnackbar.showError(context, msg);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  void dispose() {
    _myNameController.dispose();
    _myUidController.dispose();
    for (var c in _teammateControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());
    if (_tournament == null) return const Scaffold(body: StitchError(message: 'Tournament not found'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StitchCard(
              child: Column(
                children: [
                  Text(_tournament!['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StitchTheme.textMain), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Type: ${_tournament!['tournament_type'].toString().toUpperCase()}', style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Divider(color: StitchTheme.surfaceHighlight),
                  const SizedBox(height: 16),
                  const Text('Enter your details for registration', style: TextStyle(color: StitchTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            StitchCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Player 1 (Me)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: StitchTheme.textMain)),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'My In-Game Name',
                    controller: _myNameController,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'My Player UID',
                    controller: _myUidController,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  const SizedBox(height: 24),

                  if (_teammateControllers.isNotEmpty) ...[
                    const Text('Teammate Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                    const SizedBox(height: 16),
                    ...List.generate(_teammateControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: StitchInput(
                          label: 'Teammate ${index + 1} In-Game Name',
                          controller: _teammateControllers[index],
                          prefixIcon: const Icon(Icons.person_add_outlined),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
            StitchButton(
              text: 'Confirm and Join (₹${_tournament!['entry_fee']})',
              onPressed: _handleJoin,
              isLoading: _isJoining,
            ),
            const SizedBox(height: 16),
            const Text(
              'By joining, you agree to follow the tournament rules and maintain fair play.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StitchTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
