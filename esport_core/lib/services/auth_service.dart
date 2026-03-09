import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  /// Sends a password reset email to the user.
  /// The [redirectTo] should match the deep link configured in Supabase.
  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.esportadda://reset-callback',
    );
  }

  /// Updates the current user's password.
  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Logs a user activity.
  static Future<void> logActivity({
    required String userId,
    required String type,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.from('user_activity_logs').insert({
        'user_id': userId,
        'activity_type': type,
        'description': description,
        'metadata': metadata ?? {},
      });
    } catch (e) {
      // Silently fail for logging to not block main flow
      print('Activity log error: $e');
    }
  }
}
