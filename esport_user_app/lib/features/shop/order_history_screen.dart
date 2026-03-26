import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _shopService = ShopService();
  bool _isLoading = true;
  List<ShopOrder> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final orders = await _shopService.getUserOrders(userId);
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load orders: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: StitchTheme.surface,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: StitchLoading());
    }

    if (_error != null) {
      return Center(
        child: StitchError(
          message: _error!,
          onRetry: _loadOrders,
        ),
      );
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Text(
          'You have no past orders.',
          style: TextStyle(color: StitchTheme.textMuted, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _OrderCard(
          order: order,
          onCancelled: _loadOrders,
        );
      },
    );
  }
}

class _OrderCard extends StatefulWidget {
  final ShopOrder order;
  final Future<void> Function() onCancelled;

  const _OrderCard({
    required this.order,
    required this.onCancelled,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  final _shopService = ShopService();
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (widget.order.status) {
      case 'completed':
        statusColor = StitchTheme.success;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = StitchTheme.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = StitchTheme.warning;
        statusIcon = Icons.pending;
    }

    return StitchCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order',
                style: const TextStyle(
                  color: StitchTheme.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      widget.order.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Amount', style: TextStyle(color: StitchTheme.textMuted)),
              Text(
                '₹${widget.order.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: StitchTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Date', style: TextStyle(color: StitchTheme.textMuted)),
              Text(
                widget.order.createdAt != null
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(widget.order.createdAt!.toLocal())
                    : 'Unknown',
                style: const TextStyle(color: StitchTheme.textMain),
              ),
            ],
          ),
          if (widget.order.status == 'completed' && widget.order.deliveryData != null && widget.order.deliveryData!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: StitchTheme.surfaceHighlight),
            ),
            const Text(
              'Delivery Info / Code',
              style: TextStyle(
                color: StitchTheme.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StitchTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: StitchTheme.surfaceHighlight),
              ),
              child: SelectableText(
                widget.order.deliveryData!,
                style: const TextStyle(
                  color: StitchTheme.textMain,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          if (widget.order.status == 'pending') ...[
            const SizedBox(height: 16),
            StitchButton(
              text: _isCancelling ? 'Cancelling...' : 'Cancel Order',
              isLoading: _isCancelling,
              onPressed: _isCancelling
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cancel order?'),
                          content: const Text('Your wallet will be refunded.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes, cancel'),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      setState(() => _isCancelling = true);
                      try {
                        await _shopService.cancelOrder(widget.order.id);
                        if (mounted) {
                          StitchSnackbar.showSuccess(context, 'Order cancelled & refunded');
                        }
                        await widget.onCancelled();
                      } catch (e) {
                        if (mounted) {
                          StitchSnackbar.showError(context, 'Cancel failed: $e');
                        }
                      } finally {
                        if (mounted) setState(() => _isCancelling = false);
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }
}
