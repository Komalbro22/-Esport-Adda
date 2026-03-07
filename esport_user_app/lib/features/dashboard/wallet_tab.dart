import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WalletTab extends StatefulWidget {
  const WalletTab({Key? key}) : super(key: key);

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _walletStats;
  List<Map<String, dynamic>> _transactions = [];
  late TabController _tabController;
  StreamSubscription? _walletSubscription;
  StreamSubscription? _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchWalletData();
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _transactionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchWalletData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Initial Fetch
      final stats = await _supabase.from('user_wallets').select('*').eq('user_id', user.id).single();
      final txs = await _supabase.from('wallet_transactions').select('*').eq('user_id', user.id).order('created_at', ascending: false).limit(20);

      if (mounted) {
        setState(() {
          _walletStats = stats;
          _transactions = List<Map<String, dynamic>>.from(txs);
          _isLoading = false;
        });
      }

      // 2. Setup Real-time Listeners
      _walletSubscription?.cancel();
      _walletSubscription = _supabase
          .from('user_wallets')
          .stream(primaryKey: ['user_id'])
          .eq('user_id', user.id)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              setState(() => _walletStats = data.first);
            }
          });

      _transactionSubscription?.cancel();
      _transactionSubscription = _supabase
          .from('wallet_transactions')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(20)
          .listen((data) {
            if (mounted) {
              setState(() => _transactions = List<Map<String, dynamic>>.from(data));
            }
          });

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StitchSnackbar.showError(context, 'Failed to sync wallet: $e');
      }
    }
  }

  Future<void> _showAddMoney() async {
    setState(() => _isLoading = true);

    // Fetch payment settings
    String upiId = '';
    String upiName = 'Esport Adda';
    String? qrUrl;
    double minDeposit = 10;

    try {
      final settings = await _supabase.from('payment_settings').select().maybeSingle();
      if (settings != null) {
        upiId = settings['upi_id']?.toString() ?? '';
        upiName = settings['upi_name']?.toString().isNotEmpty == true
            ? settings['upi_name']
            : 'Esport Adda';
        qrUrl = settings['upi_qr_url'] ?? settings['qr_code_url'];
        minDeposit = (settings['minimum_deposit'] as num?)?.toDouble() ?? 10;
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;

    if (upiId.isEmpty) {
      StitchSnackbar.showError(context, 'Payment not configured. Contact support.');
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

  void _showWithdrawMoney() {
    final amtController = TextEditingController();
    final upiController = TextEditingController();
    
    final winningBal = _walletStats?['winning_wallet'] ?? 0;

    StitchDialog.show(
      context: context,
      title: 'Withdraw Money',
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
          } catch(e) {
            if (mounted) StitchSnackbar.showError(context, 'Failed to submit request');
          } finally {
            _fetchWalletData();
          }
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());

    final depositBal = _walletStats?['deposit_wallet'] ?? 0;
    final winningBal = _walletStats?['winning_wallet'] ?? 0;
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
              gradient: StitchTheme.primaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: StitchTheme.primary.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              children: [
                Text(
                  'TOTAL BALANCE',
                  style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${totalBal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.black, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1)
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded, color: Colors.black54, size: 14),
                      SizedBox(width: 8),
                      Text('SECURE WALLET', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                    ],
                  ),
                )
              ],
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
    
    final ScrollController txScrollController = ScrollController();
    
    return RefreshIndicator(
      onRefresh: _fetchWalletData,
      color: StitchTheme.primary,
      backgroundColor: StitchTheme.surface,
      child: Scrollbar(
        controller: txScrollController,
        child: ListView.separated(
          controller: txScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: _transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tx = _transactions[index];
            final type = tx['type'].toString();
            final isCredit = ['deposit', 'tournament_win', 'referral_bonus'].contains(type);
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
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isHighlight ? StitchTheme.success : StitchTheme.textMuted.withOpacity(0.5), size: 20),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
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
