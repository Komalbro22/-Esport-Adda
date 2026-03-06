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
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());
    if (_tournament == null) return const Scaffold(body: StitchError(message: 'Tournament not found'));

    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('REGISTRATION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        centerTitle: true,
      ),
      body: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tournament Info Summary
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: StitchTheme.primaryGradient.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: StitchTheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      _tournament!['title'].toString().toUpperCase(), 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                      textAlign: TextAlign.center
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Badge(text: _tournament!['tournament_type'].toString().toUpperCase()),
                        const SizedBox(width: 8),
                        Text(
                          'ENTRY: ₹${_tournament!['entry_fee']}', 
                          style: const TextStyle(color: StitchTheme.success, fontWeight: FontWeight.w900, fontSize: 13)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text('PLAYER DETAILS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 16),
              
              // Primary Player Data
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: StitchTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: StitchTheme.primary, size: 18),
                        SizedBox(width: 8),
                        Text('TEAM LEADER (YOU)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    StitchInput(
                      label: 'IN-GAME NAME',
                      controller: _myNameController,
                      hintText: 'Enter your exact nickname',
                    ),
                    const SizedBox(height: 16),
                    StitchInput(
                      label: 'PLAYER UID',
                      controller: _myUidController,
                      hintText: 'e.g. 54321098',
                    ),
                  ],
                ),
              ),

              if (_teammateControllers.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('TEAMMATE INFORMATION', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 16),
                ...List.generate(_teammateControllers.length, (index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: StitchTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.03)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, color: StitchTheme.textMuted.withOpacity(0.5), size: 18),
                            const SizedBox(width: 8),
                            Text('TEAMMATE ${index + 2}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StitchInput(
                          label: 'IN-GAME NAME',
                          controller: _teammateControllers[index],
                          hintText: 'Enter teammate nickname',
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 40),
              StitchButton(
                text: 'CONFIRM REGISTRATION',
                onPressed: _handleJoin,
                isLoading: _isJoining,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Incorrect details may lead to disqualification without refund.',
                        style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: StitchTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StitchTheme.primary.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }
}
