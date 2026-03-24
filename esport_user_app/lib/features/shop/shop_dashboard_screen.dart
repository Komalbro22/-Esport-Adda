import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class ShopDashboardScreen extends StatefulWidget {
  final bool isBottomNav;
  const ShopDashboardScreen({Key? key, this.isBottomNav = false}) : super(key: key);

  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  final _shopService = ShopService();
  bool _isLoading = true;
  List<ShopProduct> _products = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await _shopService.getActiveProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load products: ${e.toString()}';
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
        title: const Text('Shop'),
        backgroundColor: StitchTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => context.push('/shop/orders'),
            tooltip: 'Order History',
          ),
        ],
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
          onRetry: _loadProducts,
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Text(
          'No products available right now.',
          style: TextStyle(color: StitchTheme.textMuted, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: StitchTheme.primary,
      backgroundColor: StitchTheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return _ProductCard(
            product: product,
            onTap: () => context.push('/shop/product/${product.id}', extra: product),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ShopProduct product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StitchTheme.surfaceHighlight),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: StitchTheme.surfaceHighlight.withOpacity(0.5),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, color: StitchTheme.textMuted, size: 40),
                      )
                    : const Icon(Icons.shopping_bag, color: StitchTheme.textMuted, size: 40),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: StitchTheme.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: StitchTheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (product.category != null)
                          StitchBadge(
                            text: product.category!,
                            color: StitchTheme.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
