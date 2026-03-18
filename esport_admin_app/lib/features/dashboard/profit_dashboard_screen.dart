import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';

class ProfitDashboardScreen extends StatefulWidget {
  final bool isNested;
  const ProfitDashboardScreen({super.key, this.isNested = false});

  @override
  State<ProfitDashboardScreen> createState() => _ProfitDashboardScreenState();
}

class _ProfitDashboardScreenState extends State<ProfitDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  double _totalDeposits = 0;
  double _platformFees = 0; // Approx 2% of deposits via Razorpay
  double _totalWithdrawals = 0;
  double _tournamentCommissions = 0; 
  
  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final txs = await _supabase.from('wallet_transactions').select('amount, type').eq('status', 'completed');
      
      double deposits = 0;
      double withdraws = 0;
      
      for (var tx in txs) {
        final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        if (tx['type'] == 'deposit') {
           deposits += amt;
        } else if (tx['type'] == 'withdraw') {
           withdraws += amt;
        }
      }
      
      // Calculate 2% platform gateway fee for deposits
      final gatewayFee = deposits * 0.02;

      if (mounted) {
        setState(() {
          _totalDeposits = deposits;
          _totalWithdrawals = withdraws;
          _platformFees = gatewayFee;
          
          // Est. 10% commission on tournament entries minus some factor (placeholder).
          // Normally you'd sum up 'commission_earned' from a tournaments table.
          _tournamentCommissions = deposits * 0.10; 
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load profit analytics.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());

    final netProfit = _tournamentCommissions - _platformFees; 
    
    return Scaffold(
      backgroundColor: widget.isNested ? Colors.transparent : StitchTheme.background,
      appBar: widget.isNested ? null : AppBar(
        title: const Text('Profit Dashboard', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Platform Financials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
            const SizedBox(height: 24),
            _buildStatCard('Net Profit (Est.)', '₹${netProfit.toStringAsFixed(2)}', StitchTheme.success, isLarge: true),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard('Est. Entry Commissions', '₹${_tournamentCommissions.toStringAsFixed(2)}', StitchTheme.primary)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Gateway Fees (2%)', '₹${_platformFees.toStringAsFixed(2)}', StitchTheme.error)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('User Wallets Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Deposits', '₹${_totalDeposits.toStringAsFixed(2)}', StitchTheme.primary)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Total Withdrawals', '₹${_totalWithdrawals.toStringAsFixed(2)}', StitchTheme.warning)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color highlightColor, {bool isLarge = false}) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 32 : 24),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlightColor.withOpacity(0.3)),
        boxShadow: isLarge ? [BoxShadow(color: highlightColor.withOpacity(0.1), blurRadius: 20)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: StitchTheme.textMuted, fontSize: isLarge ? 16 : 12, fontWeight: FontWeight.bold)),
          SizedBox(height: isLarge ? 12 : 8),
          Text(value, style: TextStyle(color: Colors.white, fontSize: isLarge ? 32 : 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
