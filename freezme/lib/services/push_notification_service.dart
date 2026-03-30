import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Push notification service — keeps firebase_messaging for APNs/FCM delivery,
/// but reports the FCM token to the EC2 API instead of Firestore.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _client = ApiClient.instance;

  Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[Push] notifications authorized');
        await _saveFcmToken();
        _setupTokenRefresh();
        _setupForegroundHandler();
      }
    } catch (e) {
      debugPrint('[Push] initialization failed: $e');
    }
  }

  Future<void> _saveFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _client.dio.post('/users/fcm-token', data: {'fcmToken': token});
        debugPrint('[Push] FCM token saved to EC2');
      }
    } catch (e) {
      if (e.toString().contains('apns-token-not-set')) {
        debugPrint('[Push] APNS token not set (iOS Simulator) — skipping');
      } else {
        debugPrint('[Push] failed to save FCM token: $e');
      }
    }
  }

  void _setupTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      try {
        await _client.dio.post('/users/fcm-token', data: {'fcmToken': token});
      } catch (e) {
        debugPrint('[Push] failed to refresh FCM token on EC2: $e');
      }
    });
  }

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[Push] foreground: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[Push] opened: ${message.data}');
    });
  }

  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  Future<void> clearToken() async {
    try {
      await _client.dio.delete('/users/fcm-token');
    } catch (_) {}
  }
}
