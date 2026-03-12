import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:esport_core/esport_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VoucherHistoryScreen extends StatefulWidget {
  const VoucherHistoryScreen({Key? key}) : super(key: key);

  @override
  State<VoucherHistoryScreen> createState() => _VoucherHistoryScreenState();
}

class _VoucherHistoryScreenState extends State<VoucherHistoryScreen> {
  final _voucherService = VoucherService(Supabase.instance.client);
  List<VoucherWithdrawRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _voucherService.getUserWithdrawRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load voucher history');
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard(String code) {
     Clipboard.setData(ClipboardData(text: code));
     StitchSnackbar.showSuccess(context, 'Code copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('Voucher History', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 64, color: StitchTheme.textMuted.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      const Text('NO VOUCHER HISTORY', style: TextStyle(color: StitchTheme.textMuted, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    ],
                  )
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: StitchTheme.primary,
                  backgroundColor: StitchTheme.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final req = _requests[index];
                      
                      Color statusColor = StitchTheme.warning;
                      if (req.status == 'completed') statusColor = StitchTheme.success;
                      if (req.status == 'rejected') statusColor = StitchTheme.error;

                      return Card(
                        color: StitchTheme.surface,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.05))),
                        child: Padding(
                           padding: const EdgeInsets.all(16),
                           child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                       Text('${req.categoryName ?? 'Voucher'} - ₹${req.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                         decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                         child: Text(req.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                       )
                                    ],
                                 ),
                                 const SizedBox(height: 8),
                                 Text(DateFormat('MMM dd, yyyy • HH:mm').format(req.createdAt.toLocal()), style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                                 
                                 if (req.status == 'completed' && req.voucherCode != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                       padding: const EdgeInsets.all(12),
                                       decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: StitchTheme.primary.withOpacity(0.2))),
                                       child: Row(
                                          children: [
                                             const Icon(Icons.qr_code_rounded, color: StitchTheme.primary, size: 20),
                                             const SizedBox(width: 12),
                                             Expanded(child: SelectableText(req.voucherCode!, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                                             IconButton(
                                                icon: const Icon(Icons.copy_rounded, color: StitchTheme.textMuted, size: 18),
                                                onPressed: () => _copyToClipboard(req.voucherCode!),
                                             )
                                          ]
                                       )
                                    )
                                 ],
                                 
                                 if (req.status == 'pending') ...[
                                    const SizedBox(height: 12),
                                    const Text('Your request is being processed by admins. This may take up to 24 hours.', style: TextStyle(color: StitchTheme.warning, fontSize: 11)),
                                 ]
                              ],
                           )
                        )
                      );
                    },
                  ),
                ),
    );
  }
}
