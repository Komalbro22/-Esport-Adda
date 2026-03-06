import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

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
    String adminUpi = "Not Setup";
    String? adminQr;
    try {
      final settings = await _supabase.from('payment_settings').select().maybeSingle();
      if (settings != null) {
        if (settings['upi_id']?.toString().isNotEmpty == true) adminUpi = settings['upi_id'];
        if (settings['qr_code_url']?.toString().isNotEmpty == true) adminQr = settings['qr_code_url'];
      }
    } catch(e) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    final amtController = TextEditingController();
    XFile? selectedImage;
    bool isUploading = false;

    StitchDialog.show(
      context: context,
      title: 'Add Money',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Scan QR or Pay to UPI ID:', style: TextStyle(color: StitchTheme.textMain)),
              const SizedBox(height: 8),
              if (adminQr != null)
                Center(
                  child: Container(
                    height: 150, width: 150,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(image: NetworkImage(adminQr!), fit: BoxFit.cover)
                    )
                  )
                ),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(color: StitchTheme.background, borderRadius: BorderRadius.circular(8)),
                child: Text(adminUpi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: StitchTheme.primary), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              const Text('2. Enter details and upload screenshot', style: TextStyle(color: StitchTheme.textMain)),
              const SizedBox(height: 12),
              StitchInput(label: 'Amount (₹)', controller: amtController, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              if (selectedImage != null) 
                 const Text('Screenshot attached!', style: TextStyle(color: StitchTheme.success, fontWeight: FontWeight.bold)),
              if (selectedImage == null)
                 StitchButton(
                   text: 'Upload Screenshot', 
                   isSecondary: true, 
                   onPressed: () async {
                      final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (img != null) {
                        setDialogState(() => selectedImage = img);
                      }
                   }
                 ),
              if (isUploading) const Padding(padding: EdgeInsets.only(top: 16), child: StitchLoading())
            ],
          );
        }
      ),
      primaryButtonText: 'Submit Request',
      secondaryButtonText: 'Cancel',
      onPrimaryPressed: () async {
         final amtOpt = double.tryParse(amtController.text.trim());
         if (amtOpt == null || amtOpt <= 0 || selectedImage == null) {
           StitchSnackbar.showError(context, 'Fill amount & attach screenshot');
           return;
         }
         
         Navigator.of(context).pop({'amt': amtOpt, 'img': selectedImage});
      }
    ).then((result) async {
       if (result != null) {
          setState(() => _isLoading = true);
          
          String? url;
          try {
            final bytes = await (result['img'] as XFile).readAsBytes();
            final base64Image = base64Encode(bytes);
            final uri = Uri.parse('https://api.imgbb.com/1/upload');
            final request = http.MultipartRequest('POST', uri)
              ..fields['key'] = 'b40febb06056bca6bfdae97dde6b481c'
              ..fields['image'] = base64Image;

            final response = await request.send();
            final responseData = await response.stream.bytesToString();
            final jsonData = jsonDecode(responseData);

            if (jsonData['success'] == true) {
              url = jsonData['data']['url'];
            }
          } catch(e) {
            // Error uploading
          }

          if (url == null) {
            if (mounted) StitchSnackbar.showError(context, 'Failed to upload screenshot');
            setState(() => _isLoading = false);
            return;
          }

          try {
            final depositRes = await _supabase.from('deposit_requests').insert({
              'user_id': _supabase.auth.currentUser!.id,
              'amount': result['amt'],
              'screenshot_url': url
            }).select('id').single();
            
            // Also add pending wallet_transaction
            await _supabase.from('wallet_transactions').insert({
                'user_id': _supabase.auth.currentUser!.id,
                'amount': result['amt'],
                'type': 'deposit',
                'wallet_type': 'deposit',
                'status': 'pending',
                'reference_id': depositRes['id'].toString(),
            });
            
            if (mounted) StitchSnackbar.showSuccess(context, 'Deposit request submitted successfully! Pending admin approval.');
          } catch(e) {
            if (mounted) StitchSnackbar.showError(context, 'Failed to submit request');
          } finally {
            _fetchWalletData();
          }
       }
    });
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
