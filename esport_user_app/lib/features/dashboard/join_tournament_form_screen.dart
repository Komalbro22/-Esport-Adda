import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class JoinTournamentFormScreen extends StatefulWidget {
  final String tournamentId;
  const JoinTournamentFormScreen({super.key, required this.tournamentId});

  @override
  State<JoinTournamentFormScreen> createState() => _JoinTournamentFormScreenState();
}

class _JoinTournamentFormScreenState extends State<JoinTournamentFormScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _tournament;
  bool _isLoading = true;
  bool _isJoining = false;
  double _walletBalance = 0.0;
  
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
    _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final data = await _supabase.from('profiles').select('wallet_balance').eq('id', user.id).single();
      if (mounted) {
        setState(() {
          _walletBalance = (data['wallet_balance'] as num).toDouble();
        });
      }
    } catch (e) {
      print('Error fetching wallet balance: $e');
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
                  color: const Color(0xFF1A1C24),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2D36),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tournament!['title'].toString(),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_tournament!['tournament_type'].toString().toUpperCase()} • ${_tournament!['games']['name']?.toString() ?? 'GAME'}',
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Entry Fee', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('₹${_tournament!['entry_fee']}', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                                Text(' / player', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Prize Pool', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                            const SizedBox(height: 4),
                            const Text('₹5000', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text('Enter Player Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 20),
              
              // Primary Player Data
              _CustomInput(
                label: 'In-Game Name (IGN)',
                controller: _myNameController,
                hintText: 'e.g. Mortal, Dynamo',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _CustomInput(
                label: 'Player UID',
                controller: _myUidController,
                hintText: 'e.g. 5123456789',
                icon: Icons.numbers_rounded,
              ),
              if (_teammateControllers.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('Teammate Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 20),
                ...List.generate(_teammateControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _CustomInput(
                      label: 'Teammate ${index + 2} IGN',
                      controller: _teammateControllers[index],
                      hintText: 'Enter teammate nickname',
                      icon: Icons.group_outlined,
                    ),
                  );
                }),
              ],

              const SizedBox(height: 32),
              
              // Wallet Balance Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C24),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            const Text('Wallet Balance', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('₹${_walletBalance.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Deduction Amount', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        Text('- ₹${_tournament!['entry_fee']}', style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.white10),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining Balance', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('₹${(_walletBalance - (_tournament!['entry_fee'] as num)).toInt()}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Confirm Button
              GestureDetector(
                onTap: _isJoining ? null : _handleJoin,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9042FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: _isJoining
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Confirm & Join',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ensure your IGN and UID exactly match your game profile.\nIncorrect details will lead to disqualification without refund.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500, height: 1.4),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  const _CustomInput({required this.label, required this.controller, required this.hintText, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1C24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(icon, color: Colors.white54, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14, fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
