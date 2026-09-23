import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'auth_storage.dart';

class FcmService {
  FcmService({ApiClient? api, AuthStorage? storage, FirebaseMessaging? messaging})
      : _api = api ?? ApiClient(),
        _storage = storage ?? AuthStorage(),
        _messaging = messaging ?? FirebaseMessaging.instance;

  final ApiClient _api;
  final AuthStorage _storage;
  final FirebaseMessaging _messaging;

  /// Call after successful login (OTP verified). Requests permission on Android 13+ and iOS,
  /// gets FCM token, and registers it with backend. Supports multiple tokens per user.
  /// On iOS this triggers Apple's native permission prompt (alert/badge/sound).
  Future<String?> registerTokenAfterLogin() async {
    try {
      // iOS: triggers Apple permission prompt; Android 13+: POST_NOTIFICATIONS runtime; older Android no-op.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print('FCM permission status: ${settings.authorizationStatus}');
      }
      // iOS foreground presentation: without this, foreground notifications are silent on iOS
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      }
      final token = await _messaging.getToken();
      if (token == null) {
        if (kDebugMode) print('FCM token is null — APNs not yet available (iOS) or Google Play Services missing (Android)');
        return null;
      }
      final access = await _storage.getAccess();
      if (access == null) return token;
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      try {
        await _api.post('/api/v1/notifications/tokens', {'token': token, 'platform': platform}, token: access);
      } catch (_) {
        await _api.post('/api/v1/users/me/fcm-token', {'token': token, 'platform': platform}, token: access);
      }
      if (kDebugMode) print('FCM token registered ($platform): $token');
      return token;
    } catch (e) {
      if (kDebugMode) print('FCM register failed: $e');
      return null;
    }
  }

  Future<void> setupForegroundHandlers() async {
    // iOS: ensure foreground notifications are presented (alert/badge/sound) — Android is no-op
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    }
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('FCM onMessage foreground: ${message.messageId} ${message.notification?.title}');
      // iOS quirk: without setForegroundNotificationPresentationOptions above, foreground notifications are silent
      // For rich presentation, add flutter_local_notifications here
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) print('FCM onMessageOpenedApp: ${message.messageId}');
      // Navigate based on message.data if needed
    });
    // Handle token refresh (APNs/FCM may rotate)
    _messaging.onTokenRefresh.listen((newToken) async {
      final access = await _storage.getAccess();
      if (access == null) return;
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      try {
        await _api.post('/api/v1/notifications/tokens', {'token': newToken, 'platform': platform}, token: access);
      } catch (_) {}
    });
  }
}
