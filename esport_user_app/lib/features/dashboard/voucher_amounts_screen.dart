import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class VoucherAmountsScreen extends StatefulWidget {
  final VoucherCategory category;

  const VoucherAmountsScreen({Key? key, required this.category}) : super(key: key);

  @override
  State<VoucherAmountsScreen> createState() => _VoucherAmountsScreenState();
}

class _VoucherAmountsScreenState extends State<VoucherAmountsScreen> {
  final _voucherService = VoucherService(Supabase.instance.client);
  List<VoucherAmount> _amounts = [];
  bool _isLoading = true;
  double _userWinningBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
          final walletData = await Supabase.instance.client.from('user_wallets').select('winning_wallet').eq('user_id', user.id).single();
          _userWinningBalance = (walletData['winning_wallet'] as num).toDouble();
      }

      final amountsData = await Supabase.instance.client
          .from('voucher_amounts')
          .select()
          .eq('category_id', widget.category.id)
          .eq('status', 'active')
          .order('amount');
          
      if (mounted) {
        setState(() {
          _amounts = (amountsData as List).map((json) => VoucherAmount.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load amounts');
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmRedeem(VoucherAmount amount) async {
    if (_userWinningBalance < amount.amount) {
       StitchSnackbar.showError(context, 'Insufficient winning balance');
       return;
    }

    final confirm = await StitchDialog.show<bool>(
      context: context,
      title: 'Redeem Voucher',
      content: Text('Are you sure you want to withdraw ₹${amount.amount.toStringAsFixed(0)} for a ${widget.category.name} voucher?'),
      primaryButtonText: 'Redeem',
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      secondaryButtonText: 'Cancel',
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirm != true) return;

    if (mounted) {
       showDialog(
           context: context, 
           barrierDismissible: false, 
           builder: (_) => const Center(child: CircularProgressIndicator())
       );
    }

    try {
      final result = await _voucherService.redeemVoucher(
        categoryId: widget.category.id, 
        amount: amount.amount,
      );
      if (mounted) Navigator.pop(context); // hide loading

      if (result != null) {
        if (result['success'] == false) {
           if (mounted) StitchSnackbar.showError(context, result['error'] ?? 'Redemption failed');
           return;
        }
        
        if (result['voucher_code'] != null) {
           // Instant delivery
           _showVoucherCodeDialog(result['voucher_code']);
        } else {
           // Pending request
           _showPendingDialog();
        }
      } else {
          if (mounted) StitchSnackbar.showError(context, 'Redemption failed. Please try again later.');
      }
    } catch (e) {
       if (mounted) {
          Navigator.pop(context); // hide loading
          StitchSnackbar.showError(context, 'Error: $e');
       }
    }
  }

  void _showVoucherCodeDialog(String code) {
     showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
           backgroundColor: StitchTheme.surface,
           title: const Text('🎉 Voucher Redeemed!', style: TextStyle(color: StitchTheme.success, fontWeight: FontWeight.bold)),
           content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Text('Your ${widget.category.name} voucher is ready.', style: const TextStyle(color: Colors.white)),
                 const SizedBox(height: 24),
                 Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: StitchTheme.primary.withOpacity(0.3))),
                    child: SelectableText(code, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 2)),
                 ),
                 const SizedBox(height: 8),
                 const Text('Long press to copy', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
              ],
           ),
           actions: [
              StitchButton(
                 text: 'DONE',
                 onPressed: () {
                    Navigator.pop(context); // close dialog
                    context.pop(); // go back to categories
                 },
              )
           ],
        )
     );
  }

  void _showPendingDialog() {
     showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
           backgroundColor: StitchTheme.surface,
           title: const Text('Request Submitted', style: TextStyle(color: StitchTheme.warning, fontWeight: FontWeight.bold)),
           content: const Text('We are currently processing your request. Your voucher will be available in the History tab shortly.', style: TextStyle(color: Colors.white)),
           actions: [
              StitchButton(
                 text: 'OK',
                 onPressed: () {
                    Navigator.pop(context); // close dialog
                    context.pop(); // go back to categories
                 },
              )
           ],
        )
     );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: Text(widget.category.name, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : Column(
              children: [
                 Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(16)),
                       child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             const Text('Winning Balance', style: TextStyle(color: StitchTheme.textMuted, fontWeight: FontWeight.w900)),
                             Text('₹${_userWinningBalance.toStringAsFixed(2)}', style: const TextStyle(color: StitchTheme.success, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                       ),
                    ),
                 ),
                 Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      color: StitchTheme.primary,
                      backgroundColor: StitchTheme.surface,
                      child: _amounts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.money_off_csred_rounded, size: 64, color: StitchTheme.textMuted.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  const Text('NO AMOUNTS AVAILABLE', style: TextStyle(color: StitchTheme.textMuted, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                                ],
                              )
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _amounts.length,
                              itemBuilder: (context, index) {
                                final amount = _amounts[index];
                                final isSufficient = _userWinningBalance >= amount.amount;

                                return Card(
                                  color: StitchTheme.surface,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isSufficient ? StitchTheme.primary.withOpacity(0.3) : Colors.white10)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    leading: const CircleAvatar(backgroundColor: Colors.black26, child: Icon(Icons.currency_rupee_rounded, color: StitchTheme.primary)),
                                    title: Text('₹${amount.amount.toStringAsFixed(0)} Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isSufficient ? Colors.white : Colors.white54)),
                                    subtitle: Text(isSufficient ? 'Instant Redemption' : 'Insufficient Balance', style: TextStyle(color: isSufficient ? StitchTheme.success : StitchTheme.error, fontSize: 12)),
                                    trailing: isSufficient 
                                        ? const Icon(Icons.chevron_right_rounded, color: StitchTheme.primary)
                                        : const Icon(Icons.lock_rounded, color: StitchTheme.textMuted),
                                    onTap: isSufficient ? () => _confirmRedeem(amount) : null,
                                  ),
                                );
                              },
                            ),
                    ),
                 ),
              ],
          ),
    );
  }
}
