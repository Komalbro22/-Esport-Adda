import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:intl/intl.dart';
import 'create_promo_dialog.dart';

class PromoManagementScreen extends StatefulWidget {
  const PromoManagementScreen({Key? key}) : super(key: key);

  @override
  State<PromoManagementScreen> createState() => _PromoManagementScreenState();
}

class _PromoManagementScreenState extends State<PromoManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _promoCodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromoCodes();
  }

  Future<void> _fetchPromoCodes() async {
    try {
      final data = await _supabase
          .from('promo_codes')
          .select()
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _promoCodes = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(String id, bool currentStatus) async {
    try {
      await _supabase
          .from('promo_codes')
          .update({'is_active': !currentStatus})
          .eq('id', id);
      _fetchPromoCodes();
    } catch (e) {
      StitchSnackbar.showError(context, 'Failed to update status');
    }
  }

  Future<void> _deletePromo(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Promo Code?'),
        content: const Text('This will permanently delete the code. Users who already redeemed it will not be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('promo_codes').delete().eq('id', id);
        _fetchPromoCodes();
      } catch (e) {
        StitchSnackbar.showError(context, 'Failed to delete promo code');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo Code Management'),
        actions: [
          IconButton(
            onPressed: _fetchPromoCodes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : _promoCodes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _promoCodes.length,
                  itemBuilder: (context, index) {
                    final promo = _promoCodes[index];
                    return _buildPromoCard(promo);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => const CreatePromoDialog(),
          );
          if (result == true) _fetchPromoCodes();
        },
        label: const Text('CREATE CODE'),
        icon: const Icon(Icons.add),
        backgroundColor: StitchTheme.primary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_offer_outlined, size: 64, color: StitchTheme.textMuted),
          const SizedBox(height: 16),
          const Text('No promo codes found', style: TextStyle(color: StitchTheme.textMuted)),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: StitchButton(
              text: 'Create First Code',
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder: (context) => const CreatePromoDialog(),
                );
                if (result == true) _fetchPromoCodes();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(Map<String, dynamic> promo) {
    final expiry = promo['expires_at'] != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(promo['expires_at']))
        : 'Never';
    
    final isActive = promo['is_active'] as bool;
    final isExpired = promo['expires_at'] != null && DateTime.parse(promo['expires_at']).isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: StitchTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    promo['code'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: StitchTheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isActive,
                  onChanged: (val) => _toggleStatus(promo['id'], isActive),
                  activeColor: StitchTheme.primary,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem('Reward', '₹${promo['reward_amount']} (${promo['reward_type']})'),
                _buildInfoItem('Usage', '${promo['times_used']} / ${promo['usage_limit'] ?? '∞'}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem('Expires', expiry, color: isExpired ? Colors.red : null),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _deletePromo(promo['id']),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? StitchTheme.textMain,
          ),
        ),
      ],
    );
  }
}
