import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AdminShopDashboard extends StatefulWidget {
  const AdminShopDashboard({Key? key}) : super(key: key);

  @override
  State<AdminShopDashboard> createState() => _AdminShopDashboardState();
}

class _AdminShopDashboardState extends State<AdminShopDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _shopService = ShopService();
  bool _isLoading = true;
  List<ShopProduct> _products = [];
  List<ShopOrder> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _shopService.getAllProducts(),
        _shopService.getAllOrders(),
      ]);

      setState(() {
        _products = results[0] as List<ShopProduct>;
        _orders = results[1] as List<ShopOrder>;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load shop data: ${e.toString()}';
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
        title: const Text('Shop Management'),
        backgroundColor: StitchTheme.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StitchTheme.primary,
          tabs: const [
            Tab(text: 'PRODUCTS'),
            Tab(text: 'ORDERS'),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => context.push('/shop/product/new').then((_) => _loadData()),
              backgroundColor: StitchTheme.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: StitchLoading());

    if (_error != null) {
      return Center(
        child: StitchError(
          message: _error!,
          onRetry: _loadData,
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildProductsTab(),
        _buildOrdersTab(),
      ],
    );
  }

  Widget _buildProductsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final p = _products[index];
          return StitchCard(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: p.imageUrl != null && p.imageUrl!.isNotEmpty
                  ? Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(p.imageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : const Icon(Icons.shopping_bag, size: 40),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text('₹${p.price.toStringAsFixed(0)} • Wallet: ${p.allowedWalletType}\nStatus: ${p.isActive ? "Active" : "Inactive"}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: StitchTheme.primary),
                onPressed: () => context.push('/shop/product/${p.id}', extra: p).then((_) => _loadData()),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final o = _orders[index];
          return StitchCard(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Order #${o.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text(
                'Amount: ₹${o.amount.toStringAsFixed(0)}\nStatus: ${o.status.toUpperCase()}\nDate: ${o.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(o.createdAt!.toLocal()) : ''}',
                style: const TextStyle(color: StitchTheme.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right, color: StitchTheme.primary),
              onTap: () => context.push('/shop/order/${o.id}', extra: o).then((_) => _loadData()),
            ),
          );
        },
      ),
    );
  }
}
