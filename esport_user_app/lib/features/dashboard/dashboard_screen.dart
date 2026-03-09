import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'home_tab.dart';
import 'wallet_tab.dart';
import 'profile_tab.dart';
import 'my_matches_screen.dart';
import '../profile/global_leaderboard_screen.dart';
import '../notifications/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const MyMatchesScreen(isBottomNav: true),
    const GlobalLeaderboardScreen(isBottomNav: true),
    const ProfileTab(),
  ];

  late final StreamSubscription<AuthState> _authSubscription;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null && mounted) {
        context.go('/login');
      } else {
        NotificationService().initialize();
      }
    });
    
    // Initialize if already logged in on launch
    if (_supabase.auth.currentSession != null) {
      NotificationService().initialize();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache critical assets
    precacheImage(const AssetImage('assets/images/logo.png'), context);
    // You can also precache network images if you have their URLs early
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: StitchTheme.surfaceHighlight.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: StitchTheme.surface,
          selectedItemColor: StitchTheme.primary,
          unselectedItemColor: const Color(0xFF94A3B8),
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_esports_outlined, size: 24),
              activeIcon: Icon(Icons.sports_esports, size: 26),
              label: 'Games',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded, size: 24),
              activeIcon: Icon(Icons.history_rounded, size: 26),
              label: 'Matches',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined, size: 24),
              activeIcon: Icon(Icons.leaderboard, size: 26),
              label: 'Ranking',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              activeIcon: Icon(Icons.person_rounded, size: 26),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
