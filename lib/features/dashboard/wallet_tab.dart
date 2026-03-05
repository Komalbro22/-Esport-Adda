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
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StitchTheme.primary,
          labelColor: StitchTheme.primary,
          unselectedLabelColor: StitchTheme.textMuted,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Transactions'),
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
    return RefreshIndicator(
      onRefresh: _fetchWalletData,
      color: StitchTheme.primary,
      backgroundColor: StitchTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StitchStatCard(
            title: 'Total Balance',
            value: '₹${totalBal.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StitchStatCard(
                  title: 'Deposit',
                  value: '₹${depositBal.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StitchStatCard(
                  title: 'Winning',
                  value: '₹${winningBal.toStringAsFixed(2)}',
                  color: StitchTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: StitchButton(
                  text: 'Add Money', 
                  onPressed: _showAddMoney,
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StitchButton(
                  text: 'Withdraw', 
                  isSecondary: true,
                  onPressed: _showWithdrawMoney,
                )
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTransactions() {
    if (_transactions.isEmpty) return const Center(child: Text('No transactions yet.', style: TextStyle(color: StitchTheme.textMuted)));
    
    return RefreshIndicator(
      onRefresh: _fetchWalletData,
        color: StitchTheme.primary,
        backgroundColor: StitchTheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tx = _transactions[index];
          final type = tx['type'].toString();
          final isCredit = ['deposit', 'tournament_win', 'referral_bonus'].contains(type);
          final status = tx['status']?.toString() ?? 'completed';
          final isPending = status == 'pending';
          final isRejected = status == 'rejected';
          
          return StitchCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: (isCredit ? StitchTheme.success : StitchTheme.error).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isCredit ? StitchTheme.success : StitchTheme.error),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14)),
                          if (status != 'completed') ...[
                             const SizedBox(width: 8),
                             StitchBadge(
                               text: status,
                               color: isPending ? StitchTheme.warning : StitchTheme.error,
                             )
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(tx['created_at']).toLocal()), style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                    ],
                  )
                ),
                Text(
                  '${isCredit ? '+' : '-'}₹${tx['amount']}',
                  style: TextStyle(
                    color: isCredit ? StitchTheme.success : StitchTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  )
                )
              ],
            )
          );
        }
      ),
    );
  }
}
