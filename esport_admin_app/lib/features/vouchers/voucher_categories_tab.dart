import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherCategoriesTab extends StatefulWidget {
  const VoucherCategoriesTab({Key? key}) : super(key: key);

  @override
  State<VoucherCategoriesTab> createState() => _VoucherCategoriesTabState();
}

class _VoucherCategoriesTabState extends State<VoucherCategoriesTab> {
  final _voucherService = VoucherService(Supabase.instance.client);
  List<VoucherCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _voucherService.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load categories: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final iconUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StitchTheme.surface,
        title: const Text('Add Category', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StitchInput(
               label: 'Category Name',
               hintText: 'e.g. Google Play',
               controller: nameController,
            ),
            const SizedBox(height: 16),
            StitchInput(
               label: 'Icon URL (Optional)',
               hintText: 'https://...',
               controller: iconUrlController,
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
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await _voucherService.createCategory(
                  nameController.text.trim(),
                  iconUrlController.text.trim().isNotEmpty ? iconUrlController.text.trim() : null,
                );
                _loadCategories();
              } catch (e) {
                if (mounted) StitchSnackbar.showError(context, 'Failed: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: StitchLoading());

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Categories: ${_categories.length}', style: const TextStyle(color: StitchTheme.textMuted)),
              StitchButton(
                text: 'ADD CATEGORY',
                onPressed: _showAddCategoryDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_categories.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No categories found', style: TextStyle(color: StitchTheme.textMuted))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  color: StitchTheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: category.iconUrl != null 
                        ? Image.network(category.iconUrl!, width: 40, height: 40, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
                        : const Icon(Icons.card_giftcard_rounded, color: StitchTheme.primary),
                    title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text('Status: ${category.status}', style: TextStyle(color: category.status == 'active' ? StitchTheme.success : StitchTheme.error)),
                    trailing: Switch(
                      value: category.status == 'active',
                      activeColor: StitchTheme.primary,
                      onChanged: (val) async {
                        try {
                           await _voucherService.updateCategoryStatus(category.id, val ? 'active' : 'inactive');
                           _loadCategories();
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
