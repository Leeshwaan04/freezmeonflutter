import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Push notification service — keeps firebase_messaging for APNs/FCM delivery,
/// reports the FCM token to the EC2 API, and routes taps to the correct screen.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _client = ApiClient.instance;

  /// Routes a push payload to the relevant in-app screen. Wired from main.dart
  /// once the AppFlowController is ready. Receives `data` map from RemoteMessage.
  static void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Payload captured before [onNotificationTap] was assigned (e.g. cold start
  /// from a tapped notification). Consumed once on registration.
  Map<String, dynamic>? _pendingPayload;

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
        await _handleColdStart();
        await _sendLevelUpNudge();
      }
    } catch (e) {
      debugPrint('[Push] initialization failed: $e');
    }
  }

  Future<void> _handleColdStart() async {
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null && initial.data.isNotEmpty) {
        _dispatchTap(_normalizeData(initial.data));
      }
    } catch (e) {
      debugPrint('[Push] cold-start handler failed: $e');
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
      debugPrint('[Push] tapped (warm): ${message.data}');
      _dispatchTap(_normalizeData(message.data));
    });
  }

  void _dispatchTap(Map<String, dynamic> data) {
    final cb = onNotificationTap;
    if (cb == null) {
      // App not yet ready — stash and replay on registration.
      _pendingPayload = data;
      return;
    }
    cb(data);
  }

  /// Called by main.dart once the AppFlowController is available so any pending
  /// cold-start payload can be routed.
  void registerTapHandler(void Function(Map<String, dynamic>) handler) {
    onNotificationTap = handler;
    final pending = _pendingPayload;
    if (pending != null) {
      _pendingPayload = null;
      handler(pending);
    }
  }

  Map<String, dynamic> _normalizeData(Map<String, dynamic> data) {
    // FCM data values arrive as strings — keep them as-is.
    return Map<String, dynamic>.from(data);
  }

  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  Future<void> _sendLevelUpNudge() async {
    try {
      await _client.dio.post('/users/levelup-nudge');
      debugPrint('[Push] level-up nudge requested');
    } catch (e) {
      debugPrint('[Push] level-up nudge failed: $e');
    }
  }

  Future<void> clearToken() async {
    try {
      await _client.dio.delete('/users/fcm-token');
    } catch (_) {}
  }
}
