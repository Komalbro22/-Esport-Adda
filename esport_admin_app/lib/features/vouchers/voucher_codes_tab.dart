import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherCodesTab extends StatefulWidget {
  const VoucherCodesTab({Key? key}) : super(key: key);

  @override
  State<VoucherCodesTab> createState() => _VoucherCodesTabState();
}

class _VoucherCodesTabState extends State<VoucherCodesTab> {
  final _voucherService = VoucherService(Supabase.instance.client);
  List<VoucherCode> _codes = [];
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
      final codes = await _voucherService.getAllCodes();
      final categories = await _voucherService.getAllCategories();
      
      final amountsData = await Supabase.instance.client
          .from('voucher_amounts')
          .select()
          .order('amount');
          
      final amounts = (amountsData as List).map((json) => VoucherAmount.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _codes = codes;
          _categories = categories;
          _amounts = amounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load codes: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCodeDialog() {
    if (_categories.isEmpty || _amounts.isEmpty) {
      StitchSnackbar.showError(context, 'Create categories & amounts first');
      return;
    }

    final codeController = TextEditingController();
    String? selectedCategoryId = _categories.first.id;
    double? selectedAmount;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categoryAmounts = _amounts.where((a) => a.categoryId == selectedCategoryId).toList();
          
          // Reset amount if category changes and the amount isn't valid for the new category
          if (selectedAmount != null && !categoryAmounts.any((a) => a.amount == selectedAmount)) {
             selectedAmount = categoryAmounts.isNotEmpty ? categoryAmounts.first.amount : null;
          } else if (selectedAmount == null && categoryAmounts.isNotEmpty) {
             selectedAmount = categoryAmounts.first.amount;
          }

          return AlertDialog(
            backgroundColor: StitchTheme.surface,
            title: const Text('Add Voucher Code', style: TextStyle(color: Colors.white)),
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
                DropdownButtonFormField<double>(
                  value: selectedAmount,
                  dropdownColor: StitchTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    labelStyle: const TextStyle(color: StitchTheme.textMuted),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: categoryAmounts.map((a) => DropdownMenuItem(value: a.amount, child: Text('₹${a.amount.toStringAsFixed(0)}'))).toList(),
                  onChanged: (val) => setDialogState(() => selectedAmount = val),
                ),
                const SizedBox(height: 16),
                StitchInput(
                   label: 'Voucher Code',
                   hintText: 'ABCD-1234-EFGH',
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
                text: 'ADD',
                onPressed: () async {
                  if (codeController.text.trim().isEmpty || selectedCategoryId == null || selectedAmount == null) return;
                  Navigator.pop(context);
                  try {
                    await _voucherService.addVoucherCode(
                      selectedCategoryId!,
                      selectedAmount!,
                      codeController.text.trim(),
                    );
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

    final availableCount = _codes.where((c) => c.status == 'available').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Codes: $availableCount', style: const TextStyle(color: StitchTheme.textMuted)),
              StitchButton(
                text: 'ADD CODE',
                onPressed: _showAddCodeDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_codes.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No codes found', style: TextStyle(color: StitchTheme.textMuted))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _codes.length,
              itemBuilder: (context, index) {
                final code = _codes[index];
                final category = _categories.firstWhere((c) => c.id == code.categoryId, orElse: () => VoucherCategory(id: '', name: 'Unknown', status: '', createdAt: DateTime.now()));
                
                Color statusColor = StitchTheme.textMuted;
                if (code.status == 'available') statusColor = StitchTheme.success;
                if (code.status == 'used') statusColor = StitchTheme.error;
                if (code.status == 'reserved') statusColor = StitchTheme.warning;

                return Card(
                  color: StitchTheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: StitchTheme.primary, child: Icon(Icons.qr_code_rounded, color: Colors.white, size: 20)),
                    title: Text('${category.name} - ₹${code.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code: ${code.voucherCode}', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
                        const SizedBox(height: 4),
                        Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                               child: Text(code.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                             ),
                             if (code.usedAt != null) ...[
                               const SizedBox(width: 8),
                               Text('Used: ${code.usedAt!.toLocal()}', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
                             ]
                           ]
                        )
                      ]
                    ),
                    isThreeLine: true,
                    trailing: code.status == 'available' ? IconButton(
                      icon: const Icon(Icons.delete_rounded, color: StitchTheme.error),
                      onPressed: () async {
                         final confirm = await StitchDialog.show<bool>(
                            context: context,
                            title: 'Delete',
                            content: const Text('Are you sure you want to delete this code?'),
                            primaryButtonText: 'Delete',
                            onPrimaryPressed: () => Navigator.pop(context, true),
                            secondaryButtonText: 'Cancel',
                            onSecondaryPressed: () => Navigator.pop(context, false)
                         );
                         if (confirm == true) {
                            try {
                               await _voucherService.deleteVoucherCode(code.id);
                               _loadData();
                            } catch (e) {
                               if (mounted) StitchSnackbar.showError(context, 'Failed to delete');
                            }
                         }
                      },
                    ) : null,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
