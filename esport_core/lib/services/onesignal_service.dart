import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  // You should fill these with real IDs from OneSignal Dashboard
  static const String appId = "1399de2c-0645-4bab-b5b1-fb1ce32da972"; 

  Future<void> initialize() async {
    if (kIsWeb) return;

    // Remove this method to stop using debug logs
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    OneSignal.initialize(appId);

    // The promptForPushNotificationsWithUserResponse will show the native iOS or Android notification permission prompt.
    // We recommend removing the following code and instead using an In-App Message to prompt for notification permission
    OneSignal.Notifications.requestPermission(true);

    // Register handlers
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('Notification received in foreground: ${event.notification.body}');
    });

    OneSignal.Notifications.addClickListener((event) {
      debugPrint('Notification clicked: ${event.notification.body}');
      // Deep linking logic can be added here or via a stream
    });

    // Update Player ID in Supabase if user is logged in
    await syncPlayerId();
  }

  Future<void> syncPlayerId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) {
        try {
          await Supabase.instance.client
              .from('users')
              .update({'onesignal_player_id': playerId})
              .eq('id', user.id);
          debugPrint('OneSignal Player ID synced: $playerId');
        } catch (e) {
          debugPrint('Failed to sync OneSignal Player ID: $e');
        }
      }
    }
  }

  Future<void> logout() async {
    // Clear the player ID from the database on logout
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'onesignal_player_id': null})
            .eq('id', user.id);
      } catch (e) {
        debugPrint('Failed to clear OneSignal Player ID: $e');
      }
    }
  }
}
