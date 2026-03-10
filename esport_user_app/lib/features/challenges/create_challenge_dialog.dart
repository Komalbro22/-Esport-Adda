import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';

class CreateChallengeDialog extends StatefulWidget {
  final String gameId;
  final String gameName;

  const CreateChallengeDialog({Key? key, required this.gameId, required this.gameName}) : super(key: key);

  @override
  State<CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<CreateChallengeDialog> {
  final _supabase = Supabase.instance.client;
  final _amountController = TextEditingController();
  final _rulesController = TextEditingController();
  final _settingsController = TextEditingController();
  
  String _selectedMode = '1v1';
  int _minFairScore = 50;
  bool _isSubmitting = false;
  double _commissionPercent = 10.0;
  double _minEntryFee = 10.0;
  List<String> _allowedModes = ['1v1'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGameSettings();
    _amountController.addListener(() => setState(() {}));
  }

  Future<void> _fetchGameSettings() async {
    try {
      final data = await _supabase.from('games').select('*').eq('id', widget.gameId).single();
      setState(() {
        _commissionPercent = (data['challenge_commission_percent'] ?? 10.0).toDouble();
        _minEntryFee = (data['challenge_min_entry_fee'] ?? 10.0).toDouble();
        _allowedModes = List<String>.from(data['challenge_modes'] ?? ['1v1']);
        _selectedMode = _allowedModes.first;
        _minFairScore = 85; // Default from mockup
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _prizePool {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return 0;
    return (amount * 2) * (1 - (_commissionPercent / 100));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121421),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('CHALLENGE MODE'),
                  const SizedBox(height: 12),
                  _buildModeSelector(),
                  const SizedBox(height: 24),
                  
                  _buildSectionLabel('ENTRY FEE'),
                  const SizedBox(height: 12),
                  _buildEntryFeeInput(),
                  const SizedBox(height: 16),
                  _buildPrizePoolBox(),
                  const SizedBox(height: 24),

                  _buildSectionLabel('CHALLENGE RULES'),
                  const SizedBox(height: 12),
                  _buildLargeInput(_rulesController, 'e.g. No grenades, Sniper only, No healing items...', Icons.gavel_rounded),
                  const SizedBox(height: 24),

                  _buildSectionLabel('MATCH SETTINGS'),
                  const SizedBox(height: 12),
                  _buildLargeInput(_settingsController, 'Map: Erangel, Server: Asia, Time: 21:00', Icons.settings_rounded),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionLabel('MIN. FAIR PLAY SCORE'),
                      Text('${_minFairScore}+', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _minFairScore.toDouble(),
                    min: 30,
                    max: 100,
                    divisions: 14,
                    activeColor: Colors.greenAccent,
                    inactiveColor: Colors.white10,
                    onChanged: (v) => setState(() => _minFairScore = v.toInt()),
                  ),
                  const SizedBox(height: 32),

                  _buildCreateButton(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Create Challenge',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.greenAccent),
            onPressed: () {},
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

  Widget _buildModeSelector() {
    return Row(
      children: _allowedModes.map((mode) {
        final isSelected = _selectedMode == mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMode = mode),
            child: Container(
              margin: EdgeInsets.only(right: mode == _allowedModes.last ? 0 : 12),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? Colors.green : Colors.transparent, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    mode == '1v1' ? Icons.person : Icons.group,
                    color: isSelected ? Colors.green : Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mode == '1v1' ? '1v1 Battle' : 'Squad War',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEntryFeeInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.money_outlined, color: Colors.greenAccent),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: const InputDecoration(
                hintText: '00',
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
              ),
            ),
          ),
          const Text('COINS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPrizePoolBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Prize Pool', style: TextStyle(color: Colors.white70)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('${(100 - _commissionPercent).toInt()}% PAYOUT', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_prizePool.toStringAsFixed(0), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              const SizedBox(width: 8),
              const Text('COINS', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '*$_commissionPercent% platform commission applied for fair matchmaking and hosting.',
            style: const TextStyle(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeInput(TextEditingController controller, String hint, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white24),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          Icon(icon, color: Colors.white24, size: 20),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _createChallenge,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isSubmitting 
          ? const CircularProgressIndicator(color: Colors.black)
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_launch_rounded),
                const SizedBox(width: 12),
                Text('CREATE CHALLENGE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
      ),
    );
  }

  Future<void> _createChallenge() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < _minEntryFee) {
      StitchSnackbar.showError(context, 'Minimum entry fee is ₹${_minEntryFee.toInt()}');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await _supabase.functions.invoke(
        'manage_challenges',
        body: {
          'action': 'create_challenge',
          'game_id': widget.gameId,
          'entry_fee': amount,
          'mode': _selectedMode,
          'min_fair_score': _minFairScore,
          'rules': _rulesController.text.trim(),
          'settings': _settingsController.text.trim(),
        },
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
          'apikey': SupabaseConfig.anonKey,
        },
      );

      if (response.status != 200) throw Exception(response.data['error'] ?? 'Failed to create challenge');

      if (mounted) {
        Navigator.pop(context, true);
        StitchSnackbar.showSuccess(context, 'Challenge created successfully!');
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
