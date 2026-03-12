import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'voucher_categories_tab.dart';
import 'voucher_amounts_tab.dart';
import 'voucher_codes_tab.dart';
import 'voucher_requests_tab.dart';

class VoucherManagementScreen extends StatefulWidget {
  const VoucherManagementScreen({Key? key}) : super(key: key);

  @override
  State<VoucherManagementScreen> createState() => _VoucherManagementScreenState();
}

class _VoucherManagementScreenState extends State<VoucherManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VOUCHER MANAGEMENT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: StitchTheme.primary,
          indicatorWeight: 3,
          labelColor: StitchTheme.primary,
          unselectedLabelColor: StitchTheme.textMuted,
          tabs: const [
            Tab(text: 'CATEGORIES'),
            Tab(text: 'AMOUNTS'),
            Tab(text: 'CODES'),
            Tab(text: 'REQUESTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          VoucherCategoriesTab(),
          VoucherAmountsTab(),
          VoucherCodesTab(),
          VoucherRequestsTab(),
        ],
      ),
    );
  }
}
