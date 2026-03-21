import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_permission_service.dart';

/// Logs admin actions to the admin_activity_logs table in Supabase.
/// Fails silently — logging should never break core functionality.
class AdminLogService {
  AdminLogService._();

  static Future<void> log({
    required String action,
    String? targetType,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await Supabase.instance.client.from('admin_activity_logs').insert({
        'admin_id': AdminPermissionService.adminId.isNotEmpty
            ? AdminPermissionService.adminId
            : null,
        'admin_name': AdminPermissionService.adminName,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'details': details,
      });
    } catch (e) {
      debugPrint('Admin log insert failed (non-critical): $e');
    }
  }
}
