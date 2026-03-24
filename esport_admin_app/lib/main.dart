import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/auth/permission_guard.dart';
import 'features/dashboard/admin_dashboard_screen.dart';
import 'features/dashboard/profit_dashboard_screen.dart';
import 'features/dashboard/finance_center_screen.dart';
import 'features/games/game_management_screen.dart';
import 'features/tournaments/tournament_management_screen.dart';
import 'features/tournaments/tournament_admin_detail_screen.dart';
import 'features/wallet/deposit_management_screen.dart';
import 'features/wallet/withdraw_management_screen.dart';
import 'features/wallet/finances_screen.dart';
import 'features/assets/asset_gallery_screen.dart';
import 'features/users/user_management_screen.dart';
import 'features/users/user_detail_screen.dart';
import 'features/support/support_management_screen.dart';
import 'features/support/admin_ticket_detail_screen.dart';
import 'features/wallet/payment_settings_screen.dart';
import 'features/settings/app_settings_screen.dart';
import 'features/notifications/send_notification_screen.dart';
import 'features/admins/admin_management_screen.dart';
import 'features/admins/create_admin_screen.dart';
import 'features/admins/edit_admin_permissions_screen.dart';
import 'features/admins/admin_activity_log_screen.dart';
import 'features/users/user_activity_log_screen.dart';
import 'features/settings/legal_management_screen.dart';
import 'features/settings/blog_management_screen.dart';
import 'features/disputes/dispute_center_screen.dart';
import 'features/disputes/dispute_detail_screen.dart';
import 'features/users/fair_play_score_logs_screen.dart';
import 'features/challenges/challenge_analytics_screen.dart';
import 'features/challenges/challenge_management_screen.dart';
import 'features/vouchers/voucher_management_screen.dart';
import 'features/promo/promo_management_screen.dart';
import 'features/shop/admin_shop_dashboard.dart';
import 'features/shop/admin_product_form.dart';
import 'features/shop/admin_order_detail.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  if (!kIsWeb) {
    try {
      await OneSignalService().initialize();
    } catch (e) {
      debugPrint('OneSignal initialization failed: $e');
    }
  }

  // If there's an existing session, pre-load permissions
  if (Supabase.instance.client.auth.currentSession != null) {
    await AdminPermissionService.load();
  }

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
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageGames,
        child: const GameManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/tournaments',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageTournaments,
        child: const TournamentManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/tournament_admin/:id',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageTournaments || AdminPermissionService.canManageResults,
        child: TournamentAdminDetailScreen(tournamentId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/deposits',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageDeposits,
        child: const DepositManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/withdraws',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageWithdrawals,
        child: const WithdrawManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/finances',
      builder: (context, state) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
        return PermissionGuard(
          allowed: AdminPermissionService.canManageDeposits || AdminPermissionService.canManageWithdrawals,
          child: FinancesScreen(initialTab: tab),
        );
      },
    ),
    GoRoute(
      path: '/vouchers',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageWithdrawals,
        child: const VoucherManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/assets',
      builder: (context, state) => AssetGalleryScreen(
        isSelectionMode: state.uri.queryParameters['selection'] == 'true',
      ),
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageUsers,
        child: const UserManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/user_detail/:id',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageUsers,
        child: UserDetailScreen(userId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageSupport,
        child: const SupportManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/admin_ticket/:id',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageSupport,
        child: AdminTicketDetailScreen(ticketId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/finance_center',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canViewAnalytics || AdminPermissionService.isSuperAdmin,
        child: const FinanceCenterScreen(),
      ),
    ),
    GoRoute(
      path: '/app_settings',
      builder: (context, state) => const AppSettingsScreen(),
    ),
    GoRoute(
      path: '/send_notification',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canSendNotifications,
        child: const SendNotificationScreen(),
      ),
    ),
    // ── Admin Management routes (super_admin only) ──────────────────────────
    GoRoute(
      path: '/admin_management',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin,
        child: const AdminManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/create_admin',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin,
        child: const CreateAdminScreen(),
      ),
    ),
    GoRoute(
      path: '/edit_admin_permissions/:id',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin,
        child: EditAdminPermissionsScreen(userId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/admin_logs',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin,
        child: const AdminActivityLogScreen(),
      ),
    ),
    GoRoute(
      path: '/user_logs',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin || AdminPermissionService.canManageUsers,
        child: const UserActivityLogScreen(),
      ),
    ),
    GoRoute(
      path: '/legal_cms',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin,
        child: const LegalManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/blog_management',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin,
        child: const BlogManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/disputes',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageResults,
        child: const DisputeCenterScreen(),
      ),
    ),
    GoRoute(
      path: '/dispute_detail/:id',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageResults,
        child: DisputeDetailScreen(challengeId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/user_fair_play_logs/:userId',
      builder: (context, state) => FairPlayScoreLogsScreen(
        userId: state.pathParameters['userId']!,
        username: state.uri.queryParameters['username'],
      ),
    ),
    GoRoute(
      path: '/challenge_analytics',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canViewAnalytics,
        child: const ChallengeAnalyticsScreen(),
      ),
    ),
    GoRoute(
      path: '/challenge_management',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.canManageChallenges,
        child: const ChallengeManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/promo_codes',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin,
        child: const PromoManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin || AdminPermissionService.canManageWithdrawals,
        child: const AdminShopDashboard(),
      ),
    ),
    GoRoute(
      path: '/shop/product/new',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin || AdminPermissionService.canManageWithdrawals,
        child: const AdminProductForm(),
      ),
    ),
    GoRoute(
      path: '/shop/product/:id',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin || AdminPermissionService.canManageWithdrawals,
        child: AdminProductForm(existingProduct: state.extra as ShopProduct?),
      ),
    ),
    GoRoute(
      path: '/shop/order/:id',
      builder: (context, state) => PermissionGuard(
        allowed: AdminPermissionService.isSuperAdmin || AdminPermissionService.canManageWithdrawals,
        child: AdminOrderDetail(order: state.extra as ShopOrder),
      ),
    ),
  ],
);

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

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
