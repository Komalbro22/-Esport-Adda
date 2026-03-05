import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/tournament_list_screen.dart';
import 'features/dashboard/tournament_detail_screen.dart';
import 'features/dashboard/join_tournament_form_screen.dart';
import 'features/dashboard/my_matches_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/referral_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/profile/support_screen.dart';
import 'features/dashboard/edit_profile_screen.dart';

// User App Entry Point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Real values provided later, these are placeholder initialization
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://scdurogygxupczckioel.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjZHVyb2d5Z3h1cGN6Y2tpb2VsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MDE2MzYsImV4cCI6MjA4ODE3NzYzNn0.7j5m2MibEbEHnR46AbgncNecEXxpEGRAAwdHujKPjL0'),
  );

  runApp(const GamerApp());
}

final _router = GoRouter(
  initialLocation: Supabase.instance.client.auth.currentSession != null ? '/dashboard' : '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/tournaments/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final name = state.uri.queryParameters['name'] ?? 'Tournaments';
        return TournamentListScreen(gameId: id, gameName: name);
      },
    ),
    GoRoute(
      path: '/tournament_detail/:id',
      builder: (context, state) => TournamentDetailScreen(tournamentId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/join_tournament_form/:id',
      builder: (context, state) => JoinTournamentFormScreen(tournamentId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/my_matches',
      builder: (context, state) => const MyMatchesScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/referral',
      builder: (context, state) => const ReferralScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => const SupportScreen(),
    ),
    GoRoute(
      path: '/edit_profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
  ],
);

class GamerApp extends StatelessWidget {
  const GamerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Esports Adda',
      theme: StitchTheme.themeData,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
