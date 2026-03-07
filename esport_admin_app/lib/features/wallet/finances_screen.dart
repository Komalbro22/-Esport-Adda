import 'package:flutter/material.dart';
import 'deposit_management_screen.dart';
import 'withdraw_management_screen.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';

class FinancesScreen extends StatefulWidget {
  final int initialTab;
  const FinancesScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
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
        title: const Text('FINANCIAL MANAGEMENT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StitchTheme.primary,
          indicatorWeight: 3,
          labelColor: StitchTheme.primary,
          unselectedLabelColor: StitchTheme.textMuted,
          tabs: const [
            Tab(text: 'DEPOSITS'),
            Tab(text: 'WITHDRAWALS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DepositManagementScreen(isTab: true),
          WithdrawManagementScreen(isTab: true),
        ],
      ),
    );
  }
}
