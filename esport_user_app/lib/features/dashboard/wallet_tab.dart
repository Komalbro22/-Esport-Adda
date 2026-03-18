import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../services/payment_service.dart';

class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Performance: Using ValueNotifier for stats
  final ValueNotifier<Map<String, dynamic>?> _walletStatsNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  
  List<Map<String, dynamic>> _transactions = [];
  bool _isMoreLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 20;

  late TabController _tabController;
  final ScrollController _txScrollController = ScrollController();
  StreamSubscription? _walletSubscription;
  late final PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _txScrollController.addListener(_onTxScroll);
    _fetchWalletData();
    _paymentService = PaymentService()
      ..onPaymentSuccess = (msg) {
        if (mounted) StitchSnackbar.showSuccess(context, msg);
        _fetchWalletData();
      }
      ..onPaymentError = (msg) {
        if (mounted) StitchSnackbar.showError(context, msg);
      };
  }

  void _onTxScroll() {
    if (_txScrollController.position.pixels >= _txScrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _hasMore && _tabController.index == 1) {
        _loadMoreTransactions();
      }
    }
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _txScrollController.dispose();
    _tabController.dispose();
    _walletStatsNotifier.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Initial Fetch
      final results = await Future.wait([
        _supabase.from('user_wallets').select('*').eq('user_id', user.id).single(),
        _supabase.from('wallet_transactions')
            .select('id, type, amount, status, created_at, wallet_type')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(_pageSize),
      ]);

      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(results[1] as List);
          _hasMore = _transactions.length == _pageSize;
          _isLoading = false;
        });
        _walletStatsNotifier.value = results[0] as Map<String, dynamic>;
      }

      // 2. Setup Real-time Listener for Wallet Balance only (transactions use pagination)
      _walletSubscription?.cancel();
      _walletSubscription = _supabase
          .from('user_wallets')
          .stream(primaryKey: ['user_id'])
          .eq('user_id', user.id)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              _walletStatsNotifier.value = data.first;
            }
          });

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to sync wallet');
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isMoreLoading || !_hasMore) return;
    
    setState(() => _isMoreLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final txs = await _supabase.from('wallet_transactions')
          .select('id, type, amount, status, created_at, wallet_type')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .range(_transactions.length, _transactions.length + _pageSize - 1);

      if (mounted) {
        setState(() {
          final newTxs = List<Map<String, dynamic>>.from(txs);
          _transactions.addAll(newTxs);
          _hasMore = newTxs.length == _pageSize;
          _isMoreLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isMoreLoading = false);
    }
  }

  Future<void> _showAddMoney() async {
    setState(() => _isLoading = true);

    try {
      final settings = await _paymentService.getActivePaymentMethod();
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;

      if (settings == null) {
        StitchSnackbar.showError(context, 'Payment not configured. Contact support.');
        return;
      }

      final method = settings['active_method'] as String? ?? 'manual_upi';
      final minDeposit = (settings['min_deposit'] as num?)?.toDouble() ?? 10;

      if (method == 'razorpay') {
        _showRazorpayAmountDialog(minDeposit, settings['razorpay_key_id']?.toString() ?? '');
      } else {
        // Manual UPI Flow
        final upiId = settings['upi_id']?.toString() ?? '';
        final upiName = settings['upi_name']?.toString() ?? 'Esport Adda';
        final qrUrl = settings['upi_qr_url']?.toString();
        
        if (upiId.isEmpty) {
          StitchSnackbar.showError(context, 'UPI not configured. Contact support.');
          return;
        }

        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _DepositSheet(
            upiId: upiId,
            upiName: upiName,
            qrUrl: qrUrl,
            minDeposit: minDeposit,
            onSubmit: (double amount, String? txnId, String? screenshotUrl) async {
              setState(() => _isLoading = true);
              try {
                final depositRes = await _supabase.from('deposit_requests').insert({
                  'user_id': _supabase.auth.currentUser!.id,
                  'amount': amount,
                  'transaction_id': txnId,
                  'screenshot_url': screenshotUrl,
                  'status': 'pending',
                }).select('id').single();

                await _supabase.from('wallet_transactions').insert({
                  'user_id': _supabase.auth.currentUser!.id,
                  'amount': amount,
                  'type': 'deposit',
                  'wallet_type': 'deposit',
                  'status': 'pending',
                  'reference_id': depositRes['id'].toString(),
                });

                if (mounted) StitchSnackbar.showSuccess(context, 'Deposit request submitted! Pending admin approval.');
              } catch (e) {
                if (mounted) StitchSnackbar.showError(context, 'Failed to submit request');
              } finally {
                _fetchWalletData();
              }
            },
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to load payment settings.');
      }
    }
  }

  void _showRazorpayAmountDialog(double minDeposit, String keyId) {
    if (keyId.isEmpty) {
      StitchSnackbar.showError(context, 'Razorpay not configured properly. Contact support.');
      return;
    }

    final amtController = TextEditingController();
    
    StitchDialog.show(
      context: context,
      title: 'Add Money via Razorpay',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchInput(
            label: 'Amount to Add (₹)', 
            controller: amtController, 
            keyboardType: TextInputType.number,
            hintText: 'Min: ₹$minDeposit'
          ),
        ],
      ),
      primaryButtonText: 'Proceed to Pay',
      secondaryButtonText: 'Cancel',
      onPrimaryPressed: () async {
         final amt = double.tryParse(amtController.text.trim());
         if (amt == null || amt < minDeposit) {
           StitchSnackbar.showError(context, 'Minimum deposit is ₹$minDeposit');
           return;
         }
         Navigator.of(context).pop();
         
         // Open Razorpay
         _paymentService.openRazorpayCheckout(amount: amt, keyId: keyId);
      }
    );
  }

  void _showWithdrawMoney() {
    showModalBottomSheet(
      context: context,
      backgroundColor: StitchTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Withdraw Money', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Choose your preferred withdrawal method:', style: TextStyle(color: StitchTheme.textMuted)),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: StitchTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.account_balance_rounded, color: StitchTheme.primary),
                ),
                title: const Text('Bank Transfer / UPI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: const Text('Directly to your bank account via UPI ID', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded, color: StitchTheme.textMuted),
                onTap: () {
                  Navigator.pop(context);
                  _showUpiWithdrawDialog();
                },
              ),
              const Divider(color: Colors.white12, height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: StitchTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.card_giftcard_rounded, color: StitchTheme.success),
                ),
                title: const Text('Gift Voucher', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: const Text('Instant redemption for Google Play, Amazon, etc. (Subject to availability)', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded, color: StitchTheme.textMuted),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/withdraw/vouchers');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  void _showUpiWithdrawDialog() {
    final amtController = TextEditingController();
    final upiController = TextEditingController();
    
    final stats = _walletStatsNotifier.value;
    final winningBal = stats?['winning_wallet'] ?? 0;

    StitchDialog.show(
      context: context,
      title: 'Withdraw to UPI',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Winning Balance: ₹$winningBal', style: const TextStyle(color: StitchTheme.success, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              StitchInput(label: 'Amount to Withdraw (₹)', controller: amtController, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              StitchInput(label: 'Receive on UPI ID', controller: upiController),
            ],
          );
        }
      ),
      primaryButtonText: 'Submit Request',
      secondaryButtonText: 'Cancel',
      onPrimaryPressed: () async {
         final amtOpt = double.tryParse(amtController.text.trim());
         if (amtOpt == null || amtOpt <= 0 || upiController.text.isEmpty) {
           StitchSnackbar.showError(context, 'Fill all details correctly');
           return;
         }
         if (amtOpt > winningBal) {
           StitchSnackbar.showError(context, 'Insufficient winning balance');
           return;
         }
         Navigator.of(context).pop({'amt': amtOpt, 'upi': upiController.text.trim()});
      }
    ).then((result) async {
       if (result != null) {
          setState(() => _isLoading = true);
          try {
            final withdrawRes = await _supabase.from('withdraw_requests').insert({
              'user_id': _supabase.auth.currentUser!.id,
              'amount': result['amt'],
              'upi_id': result['upi'],
            }).select('id').single();
            // Also add pending wallet_transaction
            await _supabase.from('wallet_transactions').insert({
                'user_id': _supabase.auth.currentUser!.id,
                'amount': result['amt'],
                'type': 'withdraw',
                'wallet_type': 'winning',
                'status': 'pending',
                'reference_id': withdrawRes['id'].toString(),
            });
            if (mounted) StitchSnackbar.showSuccess(context, 'Withdraw request submitted successfully!');
            
            // Proactively update local wallet state if needed, though real-time stream should handle it.
            // The user requested that money should be debited instantly.
            // We'll also update the public.user_wallets table in the same flow or rely on a DB trigger/procedure.
            // Current code just inserts. Let's add the deduction here or ensure a DB trigger does it.
            // The user said: "when user click on withdaw... his money should be debited"
            
            final user = _supabase.auth.currentUser;
            if (user != null) {
              await _supabase.rpc('deduct_wallet_balance', params: {
                'p_user_id': user.id,
                'p_amount': result['amt'],
                'p_wallet_type': 'winning'
              });
            }
          } catch(e) {
            if (mounted) StitchSnackbar.showError(context, 'Failed to submit request: $e');
          } finally {
            _fetchWalletData();
          }
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _walletStatsNotifier,
      builder: (context, stats, child) {
        final depositBal = stats?['deposit_wallet'] ?? 0;
        final winningBal = stats?['winning_wallet'] ?? 0;
        final totalBal = depositBal + winningBal;

        return Scaffold(
          backgroundColor: StitchTheme.background,
          appBar: AppBar(
            title: const Text('FINANCIAL HUB', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: StitchTheme.primary,
              indicatorWeight: 3,
              labelColor: StitchTheme.primary,
              unselectedLabelColor: StitchTheme.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'HISTORY'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSummary(depositBal, winningBal, totalBal),
              _buildTransactions(),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSummary(dynamic depositBal, dynamic winningBal, dynamic totalBal) {
    final ScrollController summaryScrollController = ScrollController();
    
    return Scrollbar(
      controller: summaryScrollController,
      child: ListView(
        controller: summaryScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        children: [
          // Total Balance Card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StitchTheme.primary,
                  StitchTheme.primary.withOpacity(0.8),
                  const Color(0xFF00D1FF), // A subtle blue hint for depth
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: StitchTheme.primary.withOpacity(0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: Colors.black.withOpacity(0.5), size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'TOTAL BALANCE',
                      style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '₹${totalBal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.black, fontSize: 46, fontWeight: FontWeight.w900, letterSpacing: -1.5)
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQuickAction(Icons.history_rounded, 'History', () => setState(() => _tabController.animateTo(1))),
                    const SizedBox(width: 24),
                    _buildQuickAction(Icons.security_rounded, 'Secure', () {}),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Voucher Shortcut Card
          GestureDetector(
            onTap: () => context.push('/withdraw/vouchers'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StitchTheme.primary.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: StitchTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.confirmation_number_rounded, color: StitchTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MY VOUCHERS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                        SizedBox(height: 2),
                        Text('Redeem rewards & coupons', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: StitchTheme.textMuted),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: _BalanceSubCard(
                  title: 'DEPOSIT',
                  value: '₹${depositBal.toStringAsFixed(2)}',
                  icon: Icons.account_balance_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _BalanceSubCard(
                  title: 'WINNINGS',
                  value: '₹${winningBal.toStringAsFixed(2)}',
                  icon: Icons.emoji_events_rounded,
                  isHighlight: true,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          const Text('QUICK ACTIONS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: StitchButton(
                  text: 'ADD CASH', 
                  onPressed: _showAddMoney,
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StitchButton(
                  text: 'WITHDRAW', 
                  isSecondary: true,
                  onPressed: _showWithdrawMoney,
                )
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: StitchTheme.surfaceHighlight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: StitchTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.support_agent_rounded, color: StitchTheme.primary),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('24/7 SUPPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Facing payment issues?', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildVoucherHistoryShortcut(),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.black54, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildVoucherHistoryShortcut() {
    return TextButton(
      onPressed: () => context.push('/withdraw/vouchers/history'),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu_rounded, size: 16, color: StitchTheme.textMuted),
          SizedBox(width: 8),
          Text('View Voucher history →', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTransactions() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: StitchTheme.textMuted.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text('NO HISTORY YET', style: TextStyle(color: StitchTheme.textMuted, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
          ],
        )
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchWalletData,
      color: StitchTheme.primary,
      backgroundColor: StitchTheme.surface,
      child: Scrollbar(
        controller: _txScrollController,
        child: ListView.separated(
          controller: _txScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: _transactions.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == _transactions.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: StitchLoading()),
              );
            }
            final tx = _transactions[index];
            final type = tx['type'].toString();
            final isCredit = ['deposit', 'tournament_win', 'referral_bonus', 'signup_bonus'].contains(type);
            final status = tx['status']?.toString() ?? 'completed';
            final isPending = status == 'pending';
            
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StitchTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isPending ? StitchTheme.warning.withOpacity(0.1) : Colors.white.withOpacity(0.03)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isCredit ? StitchTheme.success : StitchTheme.error).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCredit ? Icons.add_rounded : Icons.remove_rounded, 
                      color: isCredit ? StitchTheme.success : StitchTheme.error,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.replaceAll('_', ' ').toUpperCase(), 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd • HH:mm').format(DateTime.parse(tx['created_at']).toLocal()), 
                          style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11)
                        ),
                      ],
                    )
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isCredit ? '+' : '-'} ₹${tx['amount']}',
                        style: TextStyle(
                          color: isCredit ? StitchTheme.success : StitchTheme.error,
                          fontWeight: FontWeight.w900,
                          fontSize: 16
                        )
                      ),
                      if (status != 'completed') ...[
                        const SizedBox(height: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: status == 'pending' ? StitchTheme.warning : StitchTheme.error,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1
                          ),
                        )
                      ]
                    ],
                  )
                ],
              )
            );
          }
        ),
      ),
    );
  }
}

class _BalanceSubCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isHighlight;

  const _BalanceSubCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceHighlight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighlight 
            ? StitchTheme.primary.withOpacity(0.3) 
            : Colors.white.withOpacity(0.05),
          width: isHighlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isHighlight ? StitchTheme.primary : StitchTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                title, 
                style: TextStyle(
                  color: isHighlight ? StitchTheme.primary : StitchTheme.textMuted, 
                  fontSize: 10, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 1
                )
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deposit Bottom Sheet — Full UPI flow
// ─────────────────────────────────────────────────────────────────────────────

class _DepositSheet extends StatefulWidget {
  final String upiId;
  final String upiName;
  final String? qrUrl;
  final double minDeposit;
  final Future<void> Function(double amount, String? txnId, String? screenshotUrl) onSubmit;

  const _DepositSheet({
    required this.upiId,
    required this.upiName,
    this.qrUrl,
    required this.minDeposit,
    required this.onSubmit,
  });

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  static const List<double> _quickAmounts = [10, 20, 50, 100, 200];

  double? _selectedAmount;
  final _customAmtCtrl = TextEditingController();
  final _txnIdCtrl = TextEditingController();
  XFile? _screenshot;
  String? _screenshotUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;
  bool _paymentDone = false; // step 2 begins after user confirms pay

  double get _amount {
    if (_selectedAmount != null) return _selectedAmount!;
    return double.tryParse(_customAmtCtrl.text.trim()) ?? 0;
  }

  bool get _isValidAmount => _amount >= widget.minDeposit;

  String _buildUpiLink(double amount) {
    final encoded = Uri.encodeComponent(widget.upiName);
    return 'upi://pay?pa=${widget.upiId}&pn=$encoded&am=${amount.toStringAsFixed(0)}&cu=INR';
  }

  Future<void> _openUPI() async {
    if (!_isValidAmount) {
      StitchSnackbar.showError(context, 'Minimum deposit is ₹${widget.minDeposit.toStringAsFixed(0)}');
      return;
    }
    final link = _buildUpiLink(_amount);
    final uri = Uri.parse(link);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Show step 2 after attempting launch
      setState(() => _paymentDone = true);
    } catch (_) {
      StitchSnackbar.showError(context, 'No UPI app found. Scan QR to pay.');
    }
  }

  Future<void> _uploadScreenshot() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    setState(() {
      _screenshot = img;
      _isUploading = true;
    });
    try {
      final bytes = await img.readAsBytes();
      final base64Image = base64Encode(bytes);
      final uri = Uri.parse('https://api.imgbb.com/1/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['key'] = 'b40febb06056bca6bfdae97dde6b481c'
        ..fields['image'] = base64Image;
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData);
      if (jsonData['success'] == true) {
        setState(() => _screenshotUrl = jsonData['data']['url']);
        StitchSnackbar.showSuccess(context, 'Screenshot attached!');
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) StitchSnackbar.showError(context, 'Upload failed. Try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submit() async {
    if (_txnIdCtrl.text.trim().isEmpty && _screenshotUrl == null) {
      StitchSnackbar.showError(context, 'Provide Transaction ID or Screenshot');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        _amount,
        _txnIdCtrl.text.trim().isEmpty ? null : _txnIdCtrl.text.trim(),
        _screenshotUrl,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Title
            const Text('Add Money', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Min deposit: ₹${widget.minDeposit.toStringAsFixed(0)}',
                style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 24),

            if (!_paymentDone) ...[
              // ── STEP 1: Select amount & pay ──
              const Text('SELECT AMOUNT', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 12),

              // Quick amount chips
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _quickAmounts.map((amt) {
                  final isSelected = _selectedAmount == amt;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedAmount = amt;
                      _customAmtCtrl.clear();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? StitchTheme.primary : StitchTheme.surfaceHighlight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? StitchTheme.primary : Colors.white12),
                      ),
                      child: Text(
                        '₹${amt.toInt()}',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Custom amount
              TextField(
                controller: _customAmtCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _selectedAmount = null),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Or enter custom amount',
                  hintStyle: const TextStyle(color: StitchTheme.textMuted),
                  prefixText: '₹  ',
                  prefixStyle: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.w900, fontSize: 18),
                  filled: true,
                  fillColor: StitchTheme.surfaceHighlight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),

              // UPI ID + QR
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: StitchTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    // QR
                    if (widget.qrUrl != null && widget.qrUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(widget.qrUrl!, height: 160, width: 160, fit: BoxFit.cover),
                      ),
                    if (widget.qrUrl != null && widget.qrUrl!.isNotEmpty)
                      const SizedBox(height: 12),
                    const Text('OR PAY TO UPI ID', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.upiId, style: const TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: widget.upiId));
                            StitchSnackbar.showSuccess(context, 'UPI ID copied!');
                          },
                          child: const Icon(Icons.copy_rounded, size: 16, color: StitchTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pay Now button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isValidAmount ? _openUPI : null,
                  icon: const Icon(Icons.payments_rounded, color: Colors.black),
                  label: Text(
                    _isValidAmount ? 'PAY ₹${_amount.toInt()} VIA UPI' : 'SELECT AMOUNT FIRST',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StitchTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: StitchTheme.surfaceHighlight,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _paymentDone = true),
                  child: const Text('Already paid? Submit details →', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                ),
              ),
            ] else ...[
              // ── STEP 2: Confirm payment ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment of ₹${_amount.toInt()} to ${widget.upiName}. Now submit your proof below.',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('PAYMENT PROOF', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 12),

              // Transaction ID
              TextField(
                controller: _txnIdCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'UPI Transaction ID (optional if screenshot given)',
                  hintStyle: const TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: StitchTheme.surfaceHighlight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.tag_rounded, color: StitchTheme.textMuted, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Screenshot upload
              GestureDetector(
                onTap: _isUploading ? null : _uploadScreenshot,
                child: Container(
                  height: _screenshotUrl != null ? 160 : 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: StitchTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _screenshotUrl != null ? Colors.green.withOpacity(0.4) : Colors.white12, width: 1.5),
                    image: _screenshotUrl != null
                        ? DecorationImage(image: NetworkImage(_screenshotUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _screenshotUrl != null
                      ? null
                      : Center(
                          child: _isUploading
                              ? const CircularProgressIndicator(color: StitchTheme.primary, strokeWidth: 2)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_photo_alternate_rounded, color: StitchTheme.textMuted, size: 28),
                                    SizedBox(height: 6),
                                    Text('Upload Payment Screenshot', style: TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
                                  ],
                                ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _paymentDone = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: StitchTheme.textMuted,
                        side: const BorderSide(color: Colors.white12),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('← Back', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StitchTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('SUBMIT REQUEST', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
