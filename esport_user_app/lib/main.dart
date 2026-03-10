import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/notifications/notification_service.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'features/auth/otp_verification_screen.dart';
import 'features/auth/profile_completion_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/profile/legal_documents_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/tournament_list_screen.dart';
import 'features/dashboard/tournament_detail_screen.dart';
import 'features/dashboard/join_tournament_form_screen.dart';
import 'features/dashboard/match_results_screen.dart';
import 'features/dashboard/my_matches_screen.dart';
import 'features/dashboard/wallet_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/global_leaderboard_screen.dart';
import 'features/profile/referral_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/support/support_home_screen.dart';
import 'features/support/create_ticket_screen.dart';
import 'features/support/support_chat_screen.dart';
import 'features/dashboard/edit_profile_screen.dart';
import 'features/profile/fair_play_leaderboard_screen.dart';
import 'features/challenges/challenge_detail_screen.dart';
import 'features/challenges/accept_challenge_screen.dart';
import 'features/challenges/room_setup_screen.dart';
import 'features/challenges/dispute_detail_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// User App Entry Point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      // Ensure messaging background handler is registered
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request permission and setup foreground listeners
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  } else {
    debugPrint('Running on Web: Firebase Cloud Messaging bypassed as it requires specific Web Firebase options configuration.');
  }

  // Real values provided later, these are placeholder initialization
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const GamerApp());
}

class GamerApp extends StatefulWidget {
  const GamerApp({Key? key}) : super(key: key);

  @override
  State<GamerApp> createState() => _GamerAppState();
}

class _GamerAppState extends State<GamerApp> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        _router.go('/reset-password');
      }
    });
  }

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

final _router = GoRouter(
  initialLocation: Supabase.instance.client.auth.currentSession != null ? '/dashboard' : '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>;
        return OTPVerificationScreen(
          email: extras['email'] as String,
          reason: extras['reason'] as OTPReason,
          signupData: extras['signupData'] as Map<String, dynamic>?,
        );
      },
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
        final initialTab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
        return TournamentListScreen(gameId: id, gameName: name, initialTabIndex: initialTab);
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
      path: '/match_results/:id',
      builder: (context, state) => MatchResultsScreen(tournamentId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/my_matches',
      builder: (context, state) => const MyMatchesScreen(),
    ),
    GoRoute(
      path: '/wallet',
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: '/global_leaderboard',
      builder: (context, state) => const GlobalLeaderboardScreen(),
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
      path: '/legal/:id',
      builder: (context, state) => LegalDocumentsScreen(docId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => const SupportHomeScreen(),
    ),
    GoRoute(
      path: '/create_ticket',
      builder: (context, state) => const CreateTicketScreen(),
    ),
    GoRoute(
      path: '/support_chat/:id',
      builder: (context, state) => SupportChatScreen(ticketId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/edit_profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/fair_play_leaderboard',
      builder: (context, state) => const FairPlayLeaderboardScreen(),
    ),
    GoRoute(
      path: '/challenge_detail/:id',
      builder: (context, state) => ChallengeDetailScreen(challengeId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/accept_challenge/:id',
      builder: (context, state) => AcceptChallengeScreen(challengeId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/room_setup/:id',
      builder: (context, state) => RoomSetupScreen(challengeId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/dispute_detail/:id',
      builder: (context, state) => DisputeDetailScreen(challengeId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/complete-profile',
      builder: (context, state) => const ProfileCompletionScreen(),
    ),
  ],
);

// DELETED GamerApp Stateless class as it is now Stateful above
