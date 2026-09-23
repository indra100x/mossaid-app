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

  /// Call after successful login (OTP verified). Requests permission on Android 13+,
  /// gets FCM token, and registers it with backend. Supports multiple tokens per user.
  Future<String?> registerTokenAfterLogin() async {
    try {
      // Android 13+ requires runtime permission; iOS always requires. No-op on older Android.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print('FCM permission status: ${settings.authorizationStatus}');
      }
      final token = await _messaging.getToken();
      if (token == null) {
        if (kDebugMode) print('FCM token is null');
        return null;
      }
      final access = await _storage.getAccess();
      if (access == null) return token; // still return token even if not yet authed
      // Try primary endpoint, fallback to users/me alias
      try {
        await _api.post('/api/v1/notifications/tokens', {'token': token, 'platform': 'android'}, token: access);
      } catch (_) {
        await _api.post('/api/v1/users/me/fcm-token', {'token': token, 'platform': 'android'}, token: access);
      }
      if (kDebugMode) print('FCM token registered: $token');
      return token;
    } catch (e) {
      if (kDebugMode) print('FCM register failed: $e');
      return null;
    }
  }

  Future<void> setupForegroundHandlers() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('FCM onMessage foreground: ${message.messageId} ${message.notification?.title}');
      // Could show local notification via flutter_local_notifications; for now just log
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) print('FCM onMessageOpenedApp: ${message.messageId}');
      // Navigate based on message.data if needed
    });
    // Handle token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      final access = await _storage.getAccess();
      if (access == null) return;
      try {
        await _api.post('/api/v1/notifications/tokens', {'token': newToken, 'platform': 'android'}, token: access);
      } catch (_) {}
    });
  }
}
