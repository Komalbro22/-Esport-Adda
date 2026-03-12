import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class VoucherCategoriesScreen extends StatefulWidget {
  const VoucherCategoriesScreen({Key? key}) : super(key: key);

  @override
  State<VoucherCategoriesScreen> createState() => _VoucherCategoriesScreenState();
}

class _VoucherCategoriesScreenState extends State<VoucherCategoriesScreen> {
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
          // Only show active categories to users
          _categories = categories.where((c) => c.status == 'active').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StitchSnackbar.showError(context, 'Failed to load voucher categories');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('Vouchers', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: StitchTheme.primary),
            tooltip: 'Voucher History',
            onPressed: () => context.push('/withdraw/vouchers/history'),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : RefreshIndicator(
              onRefresh: _loadCategories,
              color: StitchTheme.primary,
              backgroundColor: StitchTheme.surface,
              child: _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.card_giftcard_rounded, size: 64, color: StitchTheme.textMuted.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text('NO VOUCHERS AVAILABLE', style: TextStyle(color: StitchTheme.textMuted, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                        ],
                      )
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return _buildCategoryCard(category);
                      },
                    ),
            ),
    );
  }

  Widget _buildCategoryCard(VoucherCategory category) {
    return GestureDetector(
      onTap: () {
        context.push('/withdraw/vouchers/amounts', extra: category);
      },
      child: Container(
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (category.iconUrl != null && category.iconUrl!.isNotEmpty)
               ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    category.iconUrl!, 
                    height: 60, 
                    width: 60, 
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard_rounded, size: 48, color: StitchTheme.primary),
                  ),
               )
            else
               const Icon(Icons.card_giftcard_rounded, size: 48, color: StitchTheme.primary),
               
            const SizedBox(height: 16),
            Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
