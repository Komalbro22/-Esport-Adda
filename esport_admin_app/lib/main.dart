import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/dashboard/admin_dashboard_screen.dart';
import 'features/games/game_management_screen.dart';
import 'features/tournaments/tournament_management_screen.dart';
import 'features/tournaments/tournament_admin_detail_screen.dart';
import 'features/wallet/deposit_management_screen.dart';
import 'features/wallet/withdraw_management_screen.dart';
import 'features/assets/asset_gallery_screen.dart';
import 'features/users/user_management_screen.dart';
import 'features/users/user_detail_screen.dart';
import 'features/support/support_management_screen.dart';
import 'features/wallet/payment_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://scdurogygxupczckioel.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjZHVyb2d5Z3h1cGN6Y2tpb2VsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MDE2MzYsImV4cCI6MjA4ODE3NzYzNn0.7j5m2MibEbEHnR46AbgncNecEXxpEGRAAwdHujKPjL0'),
  );

  runApp(const AdminApp());
}

final _router = GoRouter(
  initialLocation: Supabase.instance.client.auth.currentSession != null ? '/dashboard' : '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/games',
      builder: (context, state) => const GameManagementScreen(),
    ),
    GoRoute(
      path: '/tournaments',
      builder: (context, state) => const TournamentManagementScreen(),
    ),
    GoRoute(
      path: '/tournament_admin/:id',
      builder: (context, state) => TournamentAdminDetailScreen(tournamentId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/deposits',
      builder: (context, state) => const DepositManagementScreen(),
    ),
    GoRoute(
      path: '/withdraws',
      builder: (context, state) => const WithdrawManagementScreen(),
    ),
    GoRoute(
      path: '/assets',
      builder: (context, state) => AssetGalleryScreen(
        isSelectionMode: state.uri.queryParameters['selection'] == 'true',
      ),
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => const UserManagementScreen(),
    ),
    GoRoute(
      path: '/user_detail/:id',
      builder: (context, state) => UserDetailScreen(userId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => const SupportManagementScreen(),
    ),
    GoRoute(
      path: '/payment_settings',
      builder: (context, state) => const PaymentSettingsScreen(),
    ),
  ],
);

class AdminApp extends StatelessWidget {
  const AdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Esport Admin Panel',
      theme: StitchTheme.themeData,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
