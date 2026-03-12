import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherRequestsTab extends StatefulWidget {
  const VoucherRequestsTab({Key? key}) : super(key: key);

  @override
  State<VoucherRequestsTab> createState() => _VoucherRequestsTabState();
}

class _VoucherRequestsTabState extends State<VoucherRequestsTab> {
  final _voucherService = VoucherService(Supabase.instance.client);
  List<VoucherWithdrawRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _voucherService.getAllWithdrawRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load requests: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFulfillDialog(VoucherWithdrawRequest request) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StitchTheme.surface,
        title: Text('Fulfill Request: ₹${request.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Category: ${request.categoryName ?? 'Unknown'}', style: const TextStyle(color: StitchTheme.textMuted)),
             Text('User: ${request.userName ?? 'Unknown'}', style: const TextStyle(color: StitchTheme.textMuted)),
             const SizedBox(height: 16),
             StitchInput(
               label: 'Purchased Voucher Code',
               hintText: 'Enter code here...',
               controller: codeController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: StitchTheme.textMuted)),
          ),
          StitchButton(
            text: 'FULFILL & SEND',
            onPressed: () async {
              if (codeController.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await _voucherService.fulfillVoucherRequest(request.id, codeController.text.trim());
                _loadData();
                if (mounted) StitchSnackbar.showSuccess(context, 'Request Fulfilled');
              } catch (e) {
                 if (mounted) StitchSnackbar.showError(context, 'Failed: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(VoucherWithdrawRequest request) async {
     final confirm = await StitchDialog.show<bool>(
        context: context, 
        title: 'Reject Request', 
        content: Text('Are you sure you want to reject this withdrawal and refund ₹${request.amount} to the user?'),
        primaryButtonText: 'Reject',
        onPrimaryPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'Cancel',
        onSecondaryPressed: () => Navigator.pop(context, false),
     );
        
     if (confirm == true) {
        try {
           await _voucherService.rejectVoucherRequest(request.id);
           _loadData();
           if (mounted) StitchSnackbar.showSuccess(context, 'Request Rejected & Refunded');
        } catch (e) {
           if (mounted) StitchSnackbar.showError(context, 'Failed to reject: $e');
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: StitchLoading());

    final pendingCount = _requests.where((r) => r.status == 'pending').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pending Requests: $pendingCount', style: const TextStyle(color: StitchTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          if (_requests.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No requests found', style: TextStyle(color: StitchTheme.textMuted))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                
                Color statusColor = StitchTheme.warning;
                if (request.status == 'completed') statusColor = StitchTheme.success;
                if (request.status == 'rejected') statusColor = StitchTheme.error;

                return Card(
                  color: StitchTheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: request.status == 'pending' ? StitchTheme.warning.withOpacity(0.3) : Colors.transparent)),
                  child: Padding(
                     padding: const EdgeInsets.all(12),
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                 Text('${request.categoryName ?? 'Voucher'} - ₹${request.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.5))),
                                   child: Text(request.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                 ),
                              ],
                           ),
                           const SizedBox(height: 8),
                           Text('User: ${request.userName ?? 'Unknown'}', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                           Text('Requested: ${request.createdAt.toLocal().toString().split('.').first}', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                           
                           if (request.status == 'completed' && request.voucherCode != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                                 child: Text('Provided Code: ${request.voucherCode}', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12)),
                              )
                           ],
                           
                           if (request.status == 'pending') ...[
                              const SizedBox(height: 16),
                              Row(
                                 mainAxisAlignment: MainAxisAlignment.end,
                                 children: [
                                    TextButton(
                                       onPressed: () => _showRejectDialog(request),
                                       child: const Text('REJECT', style: TextStyle(color: StitchTheme.error)),
                                    ),
                                    const SizedBox(width: 8),
                                    StitchButton(
                                       text: 'FULFILL',
                                       onPressed: () => _showFulfillDialog(request),

                                    )
                                 ],
                              )
                           ]
                        ],
                     ),
                  )
                );
              },
            ),
        ],
      ),
    );
  }
}
