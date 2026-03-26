import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final ShopProduct? initialProduct;

  const ProductDetailScreen({
    Key? key,
    required this.productId,
    this.initialProduct,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _shopService = ShopService();
  bool _isPurchasing = false;

  void _handlePurchase() async {
    setState(() => _isPurchasing = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final result = await _shopService.purchaseProduct(userId, widget.productId);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        StitchSnackbar.showSuccess(context, result['message']);
        context.pushReplacement('/shop/orders');
      } else {
        StitchSnackbar.showError(context, result['message']);
      }
    } catch (e) {
      if (!mounted) return;
      StitchSnackbar.showError(context, 'Purchase failed: $e');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we passed the product via route extra, use it to render instantly
    final product = widget.initialProduct;
    if (product == null) {
      return const Scaffold(
        backgroundColor: StitchTheme.background,
        body: Center(child: Text("Product not found.")),
      );
    }

    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: StitchTheme.surface,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main scrollable content.
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120), // keep space for the fixed button
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: StitchTheme.surfaceHighlight.withOpacity(0.5),
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported, color: StitchTheme.textMuted, size: 80),
                            )
                          : const Icon(Icons.shopping_bag, color: StitchTheme.textMuted, size: 80),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (product.category != null)
                              StitchBadge(
                                text: product.category!,
                                color: StitchTheme.secondary,
                              ),
                            Text(
                              '₹${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: StitchTheme.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: StitchTheme.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: StitchTheme.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description ?? 'No description available.',
                          style: const TextStyle(
                            color: StitchTheme.textMuted,
                            height: 1.5,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Fixed bottom button.
          // On Flutter Web, `Align` inside a `Stack` can accidentally expand the child.
          // Use `Positioned` + fixed height so the button stays small.
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SizedBox(
              height: 56,
              child: StitchButton(
                text: 'Buy Now',
                isLoading: _isPurchasing,
                onPressed: _handlePurchase,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
