import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'profit_dashboard_screen.dart';
import '../settings/payment_settings_screen.dart';

class FinanceCenterScreen extends StatefulWidget {
  const FinanceCenterScreen({Key? key}) : super(key: key);

  @override
  State<FinanceCenterScreen> createState() => _FinanceCenterScreenState();
}

class _FinanceCenterScreenState extends State<FinanceCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('FINANCE CENTER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 18)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StitchTheme.primary,
          indicatorWeight: 3,
          labelColor: StitchTheme.primary,
          unselectedLabelColor: StitchTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
          tabs: const [
            Tab(text: 'PROFIT ANALYTICS'),
            Tab(text: 'PAYMENT GATEWAY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ProfitDashboardScreen(isNested: true),
          PaymentSettingsScreen(isNested: true),
        ],
      ),
    );
  }
}
