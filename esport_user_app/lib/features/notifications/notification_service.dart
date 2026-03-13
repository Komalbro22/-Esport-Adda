import 'package:esport_core/esport_core.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    // Current notification system is handled by OneSignalService in esport_core
    // This wrapper is kept for backward compatibility with existing initialization calls
    if (kIsWeb) return;
    
    // OneSignal initialization is already called in main.dart, 
    // but we can ensure sync here too
    await OneSignalService().syncPlayerId();
  }
}
