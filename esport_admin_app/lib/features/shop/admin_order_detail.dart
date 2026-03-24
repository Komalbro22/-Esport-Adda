import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class AdminOrderDetail extends StatefulWidget {
  final ShopOrder order;
  const AdminOrderDetail({Key? key, required this.order}) : super(key: key);

  @override
  State<AdminOrderDetail> createState() => _AdminOrderDetailState();
}

class _AdminOrderDetailState extends State<AdminOrderDetail> {
  final _shopService = ShopService();
  bool _isSaving = false;
  late String _status;
  late TextEditingController _deliveryDataController;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _deliveryDataController = TextEditingController(text: widget.order.deliveryData ?? '');
  }

  @override
  void dispose() {
    _deliveryDataController.dispose();
    super.dispose();
  }

  Future<void> _updateOrder() async {
    setState(() => _isSaving = true);
    try {
      await _shopService.updateOrderStatus(
        widget.order.id,
        _status,
        deliveryData: _deliveryDataController.text.trim(),
      );
      StitchSnackbar.showSuccess(context, 'Order updated successfully');
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to update order: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: StitchTheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StitchCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Order ID: ${widget.order.id}',
                    style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Amount Paid: ₹${widget.order.amount.toStringAsFixed(0)}',
                    style: const TextStyle(color: StitchTheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                   Text(
                    'Paid From: ${widget.order.paidFrom?.toUpperCase() ?? "UNKNOWN"} WALLET',
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Date: ${widget.order.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(widget.order.createdAt!.toLocal()) : ''}',
                    style: const TextStyle(color: StitchTheme.textMain),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Update Status',
              style: TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: StitchTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: StitchTheme.surfaceHighlight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status,
                  dropdownColor: StitchTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
             const Text(
              'Delivery Data (Codes, Links, Tracking Info)',
              style: TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            StitchInput(
              controller: _deliveryDataController,
              label: 'Delivery Data',
              hintText: 'Enter delivery data here...',
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            StitchButton(
              text: 'Save Order',
              isLoading: _isSaving,
              onPressed: _updateOrder,
            ),
          ],
        ),
      ),
    );
  }
}
