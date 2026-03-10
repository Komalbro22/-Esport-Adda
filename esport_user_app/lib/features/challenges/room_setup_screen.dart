import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class RoomSetupScreen extends StatefulWidget {
  final String challengeId;

  const RoomSetupScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  State<RoomSetupScreen> createState() => _RoomSetupScreenState();
}

class _RoomSetupScreenState extends State<RoomSetupScreen> {
  final _supabase = Supabase.instance.client;
  final _roomIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _challenge;

  @override
  void initState() {
    super.initState();
    _fetchChallenge();
  }

  Future<void> _fetchChallenge() async {
    try {
      final data = await _supabase.from('challenges')
          .select('*, opponent:users!opponent_id(username), games(name)')
          .eq('id', widget.challengeId)
          .single();
      
      setState(() {
        _challenge = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load challenge');
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F111A),
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Room Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMatchSummary(),
            const SizedBox(height: 40),
            const Text(
              'Setup Your Lobby',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please provide the access credentials for the game room so your opponent can join.',
              style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 40),
            _buildInputField('Room ID', 'e.g. 8829-1022', _roomIdController, Icons.fingerprint_rounded),
            const SizedBox(height: 24),
            _buildInputField('Room Password', 'Enter room password', _passwordController, Icons.lock_outline_rounded, isPassword: true),
            const SizedBox(height: 64),
            _buildSubmitButton(),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.white24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Once submitted, details will be shared with the opponent.',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text('ACTIVE CHALLENGE', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 12),
          Text(
            '${_challenge!['games']['name']} ${_challenge!['mode']}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 16),
          _buildSummaryDetail(Icons.person_outline_rounded, 'Opponent:', _challenge!['opponent']?['username'] ?? 'TBD', valueColor: Colors.deepPurpleAccent),
          const SizedBox(height: 12),
          _buildSummaryDetail(Icons.payments_outlined, 'Entry Fee:', '₹${_challenge!['entry_fee']} Credits'),
        ],
      ),
    );
  }

  Widget _buildSummaryDetail(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildInputField(String label, String hint, TextEditingController controller, IconData icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 15),
              prefixIcon: Icon(icon, color: Colors.white24, size: 20),
              suffixIcon: isPassword ? const Icon(Icons.visibility_outlined, color: Colors.white24, size: 20) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitDetails,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 8,
          shadowColor: const Color(0xFF7C4DFF).withOpacity(0.4),
        ),
        child: _isSubmitting 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Submit Room Details',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                ),
                SizedBox(width: 12),
                Icon(Icons.rocket_launch_rounded, size: 24),
              ],
            ),
      ),
    );
  }

  Future<void> _submitDetails() async {
    if (_roomIdController.text.isEmpty || _passwordController.text.isEmpty) {
      StitchSnackbar.showError(context, 'Please fill all details');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _supabase.functions.invoke(
        'manage_challenges',
        body: {
          'action': 'enter_room_details',
          'challenge_id': widget.challengeId,
          'room_id': _roomIdController.text.trim(),
          'room_pass': _passwordController.text.trim(),
        },
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
          'apikey': SupabaseConfig.anonKey,
        },
      );

      if (response.status != 200) throw Exception(response.data['error'] ?? 'Failed to submit');

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Lobby details shared!');
        context.pop();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
