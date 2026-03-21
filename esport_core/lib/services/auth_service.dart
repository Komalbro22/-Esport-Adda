import 'package:flutter/foundation.dart';
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

  /// Sends a 6-digit OTP to the user's email for both Login and Signup.
  static Future<void> signInWithOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true, // This allows new users to register via OTP
    );
  }

  /// Generates a unique 5-character referral code (ESD + 5 chars).
  static String generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Cleaned alphanumeric (no I, O, 0, 1)
    final random = DateTime.now().microsecondsSinceEpoch;
    final suffix = List.generate(5, (index) => chars[(random + index) % chars.length]).join();
    return 'ESD$suffix';
  }

  /// Updates the current user's password.
  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Verifies the OTP sent to the user's email.
  static Future<void> verifyOTP({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: type,
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
      debugPrint('Activity log error: $e');
    }
  }
}
