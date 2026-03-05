import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  late final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Return immediately if running on Web since FCM isn't configured for it yet.
    if (kIsWeb) return;

    // Background listener setup done in main.dart
    
    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Local notifications for foreground display
      const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);
      await _localNotifications.initialize(initSettings);

      // Create high importance channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // name
        description: 'This channel is used for important notifications.', // description
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android.smallIcon,
              ),
            ),
          );
        }
      });

      // Save token to Supabase
      await _saveTokenToDatabase();

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _updateTokenInDatabase(newToken);
      });
    }
  }

  Future<void> _saveTokenToDatabase() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _updateTokenInDatabase(token);
    }
  }

  Future<void> _updateTokenInDatabase(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': token})
            .eq('id', user.id);
      } catch (e) {
        debugPrint('Failed to save FCM token: $e');
      }
    }
  }
}
