import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _challenge;
  final String _imgbbApiKey = 'b40febb06056bca6bfdae97dde6b481c';

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    try {
      final data = await _supabase.from('challenges')
          .select('*, creator:users!creator_id(username, fair_score, avatar_url), opponent:users!opponent_id(username, fair_score, avatar_url), games(name, logo_url)')
          .eq('id', widget.challengeId)
          .single();
      if (mounted) {
        setState(() {
          _challenge = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load challenge details');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_challenge == null) return const Scaffold(body: Center(child: Text('Challenge not found')));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('challenges').stream(primaryKey: ['id']).eq('id', widget.challengeId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          _challenge = { ..._challenge!, ...snapshot.data!.first };
        }
        return _buildBody();
      },
    );
  }

  Widget _buildBody() {
    final status = _challenge!['status'];
    final user = _supabase.auth.currentUser;
    final isCreator = _challenge!['creator_id'] == user?.id;
    final isOpponent = _challenge!['opponent_id'] == user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('Match Detail: ${status.toString().toUpperCase()}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildMatchCard(),
            const SizedBox(height: 24),
            if (status == 'accepted') _buildReadySection(isCreator, isOpponent),
            if (status == 'ready' && isCreator) _buildRoomEntryForm(),
            if (status == 'ready' && isOpponent) _buildWaitingForRoom(),
            if (status == 'ongoing') _buildResultSubmissionSection(),
            if (status == 'completed' || status == 'dispute') _buildMatchStatusInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPlayerInfo(_challenge!['creator']['username'], 'Creator', _challenge!['creator']['avatar_url']),
              Column(
                children: [
                   const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.deepPurpleAccent, fontSize: 24, letterSpacing: 2)),
                   if (_challenge!['opponent_id'] != null && _challenge!['opponent_id'] != _supabase.auth.currentUser?.id)
                     TextButton.icon(
                       onPressed: _blockOpponent,
                       icon: const Icon(Icons.block, size: 14, color: Colors.white24),
                       label: const Text('BLOCK', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                     ),
                ],
              ),
              _buildPlayerInfo(_challenge!['opponent']?['username'] ?? 'Waiting...', 'Opponent', _challenge!['opponent']?['avatar_url']),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Entry Fee', '₹${_challenge!['entry_fee']}'),
              _buildMiniStat('Mode', _challenge!['mode'].toString().toUpperCase()),
              _buildMiniStat('Game', _challenge!['games']['name'].toString().toUpperCase()),
            ],
          ),
          if (_challenge!['games']?['logo_url'] != null) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: _challenge!['games']['logo_url'],
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.3),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(String name, String label, String? avatarUrl) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24, 
          backgroundColor: Colors.white10, 
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
          child: avatarUrl == null || avatarUrl.isEmpty ? Text(name[0].toUpperCase()) : null,
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildReadySection(bool isCreator, bool isOpponent) {
    bool myReady = isCreator ? _challenge!['creator_ready'] == true : _challenge!['opponent_ready'] == true;
    return Column(
      children: [
        const Text('Confirm Readiness within 5 minutes', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: myReady ? null : _confirmReady,
            style: ElevatedButton.styleFrom(backgroundColor: myReady ? Colors.green : StitchTheme.primary),
            child: Text(myReady ? 'WAITING FOR OPPONENT' : 'CONFIRM READY'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReady() async {
    try {
      final response = await _supabase.functions.invoke(
        'manage_challenges',
        body: {
          'action': 'confirm_ready',
          'challenge_id': widget.challengeId,
        },
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
          'apikey': SupabaseConfig.anonKey,
        },
      );
      if (response.status != 200) throw Exception(response.data['error']);
      StitchSnackbar.showSuccess(context, 'Ready confirmed!');
    } catch (e) {
      StitchSnackbar.showError(context, e.toString());
    }
  }

  final _roomIdCtrl = TextEditingController();
  final _roomPassCtrl = TextEditingController();

  Widget _buildRoomEntryForm() {
    return Column(
      children: [
        const Text('Enter Room Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        const SizedBox(height: 16),
        StitchInput(label: 'Room ID', controller: _roomIdCtrl, hintText: 'Enter room ID'),
        const SizedBox(height: 12),
        StitchInput(label: 'Password', controller: _roomPassCtrl, hintText: 'Enter room password'),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _enterRoomDetails(_roomIdCtrl.text, _roomPassCtrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF), // Matching cyan in screenshot
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('READY TO PLAY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Future<void> _enterRoomDetails(String id, String pass) async {
    if (id.isEmpty) return;
    try {
      final response = await _supabase.functions.invoke(
        'manage_challenges',
        body: {
          'action': 'enter_room_details',
          'challenge_id': widget.challengeId,
          'room_id': id,
          'room_password': pass,
        },
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
          'apikey': SupabaseConfig.anonKey,
        },
      );
      if (response.status != 200) throw Exception(response.data['error'] ?? 'Room creation failed');
      StitchSnackbar.showSuccess(context, 'Match is now live!');
    } catch (e) {
      StitchSnackbar.showError(context, e.toString());
    }
  }

  Widget _buildWaitingForRoom() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Opponent is creating the room...'),
      ],
    );
  }

  String _selectedResult = '';
  final _videoProofCtrl = TextEditingController();
  XFile? _selectedScreenshot;

  Widget _buildResultSubmissionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRoomCredentialsBox(),
        const SizedBox(height: 24),
        _buildSectionLabel('SELECT YOUR RESULT'),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildResultButton('win', 'I WON', Colors.greenAccent, Icons.emoji_events_rounded),
            const SizedBox(width: 16),
            _buildResultButton('lose', 'I LOST', Colors.redAccent, Icons.sentiment_very_dissatisfied_rounded),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionLabel('UPLOAD SCREENSHOT'),
        const SizedBox(height: 12),
        _buildScreenshotUploadArea(),
        const SizedBox(height: 24),
        _buildSectionLabel('VIDEO PROOF (OPTIONAL)'),
        const SizedBox(height: 12),
        _buildVideoProofInput(),
        const SizedBox(height: 32),
        _buildSubmitButton(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRoomCredentialsBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 12),
              Text('Room Credentials', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 32, color: Colors.white10),
          Row(
            children: [
              _buildCredentialItem('ROOM ID', _challenge!['room_id'] ?? 'N/A'),
              Container(width: 1, height: 40, color: Colors.white10),
              _buildCredentialItem('PASSWORD', _challenge!['room_password'] ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.amber),
                onPressed: () {}, // Add copy logic
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }

  Widget _buildResultButton(String result, String label, Color color, IconData icon) {
    final isSelected = _selectedResult == result;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedResult = result),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.white24, size: 24),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: isSelected ? color : Colors.white54, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenshotUploadArea() {
    return GestureDetector(
      onTap: _pickScreenshot,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10, width: 1, style: BorderStyle.solid), // In a real app, use a custom painter for dashed border
        ),
        child: _selectedScreenshot != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: kIsWeb 
                ? Image.network(_selectedScreenshot!.path, fit: BoxFit.cover)
                : Image.file(File(_selectedScreenshot!.path), fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.deepPurpleAccent.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text('Click to upload screenshot', style: TextStyle(color: Colors.white38, fontSize: 12)),
                const Text('Max size 5MB • JPG, PNG', style: TextStyle(color: Colors.white10, fontSize: 10)),
              ],
            ),
      ),
    );
  }

  Widget _buildVideoProofInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: _videoProofCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Paste YouTube/Drive link here...',
          hintStyle: TextStyle(color: Colors.white10),
          border: InputBorder.none,
          icon: Icon(Icons.link_rounded, color: Colors.white24, size: 20),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool canSubmit = _selectedResult.isNotEmpty && _selectedScreenshot != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canSubmit && !_isSubmitting ? _submitFinalResult : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurpleAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isSubmitting 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('SUBMIT FOR REVIEW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedScreenshot = image);
  }

  bool _isSubmitting = false;

  Future<void> _submitFinalResult() async {
    if (_selectedScreenshot == null) return;
    setState(() => _isSubmitting = true);
    
    try {
      StitchSnackbar.showLoading(context, 'Processing image...');
      
      final bytes = await _selectedScreenshot!.readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) throw 'Failed to decode image';

      // Watermark
      final now = DateTime.now().toIso8601String();
      final watermarkText = 'CH_ID: ${widget.challengeId}\nUSER: ${_supabase.auth.currentUser!.id}\n$now';
      img.drawString(decoded, watermarkText, font: img.arial24, x: 20, y: 20, color: img.ColorRgba8(255, 255, 255, 128));

      final watermarkedBytes = img.encodeJpg(decoded);
      final hash = sha256.convert(watermarkedBytes).toString();
      
      final base64Image = base64Encode(watermarkedBytes);
      final uploadRes = await http.post(Uri.parse('https://api.imgbb.com/1/upload'), body: {
        'key': _imgbbApiKey,
        'image': base64Image,
      });
      
      if (uploadRes.statusCode != 200) throw 'Upload failed';
      final url = jsonDecode(uploadRes.body)['data']['url'];

      final response = await _supabase.functions.invoke('manage_challenges', body: {
        'action': 'submit_result',
        'challenge_id': widget.challengeId,
        'result': _selectedResult,
        'screenshot_url': url,
        'screenshot_hash': hash,
        'video_url': _videoProofCtrl.text.trim(),
      });

      if (response.status != 200) throw response.data['error'] ?? 'Submission failed';
      
      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Result submitted successfully!');
        _loadChallenge();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _blockOpponent() async {
    final opponentId = _challenge!['creator_id'] == _supabase.auth.currentUser!.id 
      ? _challenge!['opponent_id'] 
      : _challenge!['creator_id'];
    
    if (opponentId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StitchTheme.surface,
        title: const Text('Block User?'),
        content: const Text('You will no longer see challenges from this user or be able to interact with them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('BLOCK'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('blocked_users').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'blocked_user_id': opponentId,
      });
      if (mounted) {
        StitchSnackbar.showSuccess(context, 'User blocked successfully');
        context.pop();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to block user');
    }
  }

  Widget _buildMatchStatusInfo() {
    final status = _challenge!['status'];
    final winnerId = _challenge!['winner_id'];
    final userId = _supabase.auth.currentUser!.id;
    final isWinner = winnerId == userId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWinner ? Colors.green.withOpacity(0.3) : Colors.white12),
      ),
      child: Column(
        children: [
          Icon(
            status == 'completed' ? Icons.emoji_events : Icons.gavel_rounded,
            size: 48,
            color: status == 'completed' ? Colors.amber : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            status == 'completed' 
              ? (isWinner ? 'YOU WON!' : 'MATCH COMPLETED') 
              : 'MATCH IN DISPUTE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: status == 'completed' ? Colors.white : Colors.orangeAccent
            ),
          ),
          if (status == 'completed') ...[
            const SizedBox(height: 8),
            Text(
              isWinner ? 'Winner Prize added to your wallet' : 'Better luck next time!',
              style: TextStyle(color: StitchTheme.textMuted),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Admin is reviewing the results.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
          const Divider(height: 48, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('Entry Fee', '₹${_challenge!['entry_fee']}'),
              if (status == 'completed')
                _buildMiniStat('Winner Prize', '₹${(_challenge!['entry_fee'] * 2 * (1 - (_challenge!['commission_percent'] ?? 10) / 100)).toStringAsFixed(2)}'),
              _buildMiniStat('Game', _challenge!['games']?['name'] ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }
}
