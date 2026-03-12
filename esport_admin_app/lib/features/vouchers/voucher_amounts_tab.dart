import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherAmountsTab extends StatefulWidget {
  const VoucherAmountsTab({Key? key}) : super(key: key);

  @override
  State<VoucherAmountsTab> createState() => _VoucherAmountsTabState();
}

class _VoucherAmountsTabState extends State<VoucherAmountsTab> {
  final _voucherService = VoucherService(Supabase.instance.client);
  List<VoucherCategory> _categories = [];
  List<VoucherAmount> _amounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _voucherService.getAllCategories();
      // Fetch amounts for all categories to show in a combined list
      // For simplicity, we just fetch each amount based on category...
      // Or we can just use a raw Supabase query here for convenience
      final amountsData = await Supabase.instance.client
          .from('voucher_amounts')
          .select('*, voucher_categories(name)')
          .order('amount');
          
      final amounts = (amountsData as List).map((json) {
        final amt = VoucherAmount.fromJson(json);
        // We'll hijack a local mapping for UI display
        return MapEntry(amt, json['voucher_categories']?['name'] ?? 'Unknown');
      }).toList();

      if (mounted) {
        setState(() {
          _categories = categories;
          _amounts = amounts.map((e) => e.key).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load amounts: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddAmountDialog() {
    if (_categories.isEmpty) {
      StitchSnackbar.showError(context, 'Create a category first!');
      return;
    }
    
    final amountController = TextEditingController();
    String? selectedCategoryId = _categories.first.id;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: StitchTheme.surface,
            title: const Text('Add Amount', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  dropdownColor: StitchTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: const TextStyle(color: StitchTheme.textMuted),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                ),
                const SizedBox(height: 16),
                StitchInput(
                   label: 'Amount (₹)',
                   hintText: 'e.g. 50',
                   controller: amountController,
                   keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(color: StitchTheme.textMuted)),
              ),
              StitchButton(
                text: 'ADD',
                onPressed: () async {
                  final amt = double.tryParse(amountController.text.trim());
                  if (amt == null || amt <= 0) {
                     StitchSnackbar.showError(context, 'Enter a valid amount');
                     return;
                  }
                  Navigator.pop(context);
                  try {
                    await _voucherService.createAmount(selectedCategoryId!, amt);
                    _loadData();
                  } catch (e) {
                    if (mounted) StitchSnackbar.showError(context, 'Failed: $e');
                  }
                },
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: StitchLoading());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amounts: ${_amounts.length}', style: const TextStyle(color: StitchTheme.textMuted)),
              StitchButton(
                text: 'ADD AMOUNT',
                onPressed: _showAddAmountDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_amounts.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No amounts found', style: TextStyle(color: StitchTheme.textMuted))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _amounts.length,
              itemBuilder: (context, index) {
                final amount = _amounts[index];
                final category = _categories.firstWhere((c) => c.id == amount.categoryId, orElse: () => VoucherCategory(id: '', name: 'Unknown', status: '', createdAt: DateTime.now()));
                
                return Card(
                  color: StitchTheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: StitchTheme.primary, child: Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 20)),
                    title: Text('${category.name} - ₹${amount.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text('Status: ${amount.status}', style: TextStyle(color: amount.status == 'active' ? StitchTheme.success : StitchTheme.error)),
                    trailing: Switch(
                      value: amount.status == 'active',
                      activeColor: StitchTheme.primary,
                      onChanged: (val) async {
                        try {
                           await _voucherService.updateAmountStatus(amount.id, val ? 'active' : 'inactive');
                           _loadData();
                        } catch (e) {
                          if (mounted) StitchSnackbar.showError(context, 'Failed to update status');
                        }
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
