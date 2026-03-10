import 'package:supabase_flutter/supabase_flutter.dart';

/// Holds the current admin's role and permissions in memory after login.
/// Call [load] after successful auth sign-in.
/// Call [clear] on sign-out.
class AdminPermissionService {
  AdminPermissionService._();

  static String _role = '';
  static bool _loaded = false;
  static Map<String, dynamic> _perms = {};
  static String _adminName = '';
  static String _adminId = '';

  // ── Public getters ────────────────────────────────────────────────────────

  static bool get isSuperAdmin => _role == 'super_admin';

  static bool get canManageGames =>
      isSuperAdmin || (_perms['can_manage_games'] == true);

  static bool get canManageTournaments =>
      isSuperAdmin || (_perms['can_manage_tournaments'] == true);

  static bool get canManageResults =>
      isSuperAdmin || (_perms['can_manage_results'] == true);

  static bool get canManageDeposits =>
      isSuperAdmin || (_perms['can_manage_deposits'] == true);

  static bool get canManageWithdrawals =>
      isSuperAdmin || (_perms['can_manage_withdrawals'] == true);

  static bool get canManageUsers =>
      isSuperAdmin || (_perms['can_manage_users'] == true);

  static bool get canSendNotifications =>
      isSuperAdmin || (_perms['can_send_notifications'] == true);

  static bool get canManageSupport =>
      isSuperAdmin ||
      (_perms['can_manage_support'] == true) ||
      (_perms['can_manage_users'] == true);

  static bool get canManageChallenges =>
      isSuperAdmin || (_perms['can_manage_challenges'] == true);

  static bool get canViewAnalytics =>
      isSuperAdmin || (_perms['can_view_analytics'] != false);

  static bool get canViewDashboard =>
      isSuperAdmin || (_perms['can_view_dashboard'] != false);

  static bool get loaded => _loaded;
  static String get adminName => _adminName;
  static String get adminId => _adminId;
  static String get role => _role;

  // ── Load / Clear ──────────────────────────────────────────────────────────

  /// Fetches role + permissions from Supabase and caches them.
  static Future<void> load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final user = await Supabase.instance.client
          .from('users')
          .select('id, name, role, is_blocked')
          .eq('id', uid)
          .single();

      _role = user['role'] ?? '';
      _adminName = user['name'] ?? '';
      _adminId = user['id'] ?? '';

      if (_role == 'admin') {
        try {
          final perms = await Supabase.instance.client
              .from('admin_permissions')
              .select()
              .eq('user_id', uid)
              .maybeSingle();
          _perms = perms ?? {};
        } catch (_) {
          _perms = {};
        }
      } else {
        _perms = {};
      }

      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
  }

  /// Clears cached permissions on logout.
  static void clear() {
    _role = '';
    _perms = {};
    _adminName = '';
    _adminId = '';
    _loaded = false;
  }
}
