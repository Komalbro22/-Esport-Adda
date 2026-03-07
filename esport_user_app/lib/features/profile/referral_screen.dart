import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _referralCode = '';
  int _totalReferrals = 0;
  double _earnings = 0;

  @override
  void initState() {
    super.initState();
    _fetchReferralData();
  }

  Future<void> _fetchReferralData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userData = await _supabase.from('users').select('referral_code').eq('id', userId).single();
      
      // Count referrals
      final referralResponse = await _supabase
          .from('users')
          .select('id')
          .eq('referred_by', userData['referral_code'])
          .count(CountOption.exact);
      
      final totalReferrals = referralResponse.count ?? 0;
      
      // Calculate earnings from transactions
      final earningsResponse = await _supabase
          .from('wallet_transactions')
          .select('amount')
          .eq('user_id', userId)
          .eq('type', 'referral_bonus');

      double totalEarnings = 0;
      for (var tx in earningsResponse) {
        totalEarnings += (tx['amount'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _referralCode = userData['referral_code'] ?? 'N/A';
          _totalReferrals = totalReferrals;
          _earnings = totalEarnings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    StitchSnackbar.showSuccess(context, 'Referral code copied!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: _isLoading 
          ? const Center(child: StitchLoading()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.card_giftcard, size: 80, color: StitchTheme.primary),
                  const SizedBox(height: 24),
                  const Text(
                    'Invite your friends and earn rewards!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StitchTheme.textMain),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Share your referral code with friends. When they join and play, you earn bonuses!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: StitchTheme.textMuted),
                  ),
                  const SizedBox(height: 40),
                  
                  // Referral Code Card
                  StitchCard(
                    child: Column(
                      children: [
                        const Text('YOUR REFERRAL CODE', style: TextStyle(fontSize: 12, color: StitchTheme.textMuted, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _referralCode,
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: StitchTheme.primary, letterSpacing: 2),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: _copyCode,
                              icon: const Icon(Icons.copy, color: StitchTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Referrals', _totalReferrals.toString(), Icons.people_outline),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Total Earnings', '₹${_earnings.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  StitchButton(
                    text: 'Copy Invite Message',
                    onPressed: () {
                      final message = 'Join Esport Adda to play tournaments and earn real money! Use my referral code $_referralCode to get an instant signup bonus. Download now!';
                      Clipboard.setData(ClipboardData(text: message));
                      StitchSnackbar.showSuccess(context, 'Invite message copied to clipboard!');
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return StitchCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: StitchTheme.primary, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
          Text(label, style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
        ],
      ),
    );
  }
}
