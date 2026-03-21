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
  List<Map<String, dynamic>> _referredUsers = [];

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
      final myCode = userData['referral_code'];
      
      // Fetch referred users list
      final referredResponse = await _supabase
          .from('users')
          .select('username, name, created_at')
          .eq('referred_by', myCode)
          .order('created_at', ascending: false);
      
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
          _referralCode = myCode ?? 'N/A';
          _referredUsers = List<Map<String, dynamic>>.from(referredResponse);
          _totalReferrals = _referredUsers.length;
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
                  
                  const SizedBox(height: 48),
                  
                  // Referrals List
                  Row(
                    children: [
                      const Text(
                        'MY REFERRALS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: StitchTheme.textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_totalReferrals Users',
                        style: const TextStyle(fontSize: 12, color: StitchTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (_referredUsers.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: StitchTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.people_alt_outlined, size: 32, color: StitchTheme.textMuted),
                          SizedBox(height: 12),
                          Text('No referrals yet', style: TextStyle(color: StitchTheme.textMuted)),
                        ],
                       ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _referredUsers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = _referredUsers[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: StitchTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: StitchTheme.primary.withOpacity(0.1),
                                child: Text(
                                  (user['username'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['username'] ?? 'User',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain),
                                    ),
                                    Text(
                                      _formatDate(user['created_at']),
                                      style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const Text(
                                'Joined',
                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      debugPrint('Invalid date format: $dateStr - $e');
      return '';
    }
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
