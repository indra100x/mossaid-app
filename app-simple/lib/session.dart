import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Holds auth state (token + user) and persists the token on device.
class Session extends ChangeNotifier {
  Session(this.api);
  final ApiClient api;
  Map<String, dynamic>? user;
  bool loaded = false;

  bool get loggedIn => user != null;
  bool get isCraftsman => user?['role'] == 'craftsman';
  String? get name => user?['name'] as String?;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      api.token = token;
      try {
        user = await api.me();
      } catch (_) {
        api.token = null;
        await prefs.remove('token');
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<String?> auth({
    required bool isLogin,
    required String name,
    required String email,
    required String password,
    required String role,
    String? city,
  }) async {
    try {
      final body = isLogin
          ? await api.login(email, password)
          : await api.register(
              name: name,
              email: email,
              password: password,
              role: role,
              city: city,
            );
      api.token = body['token'] as String?;
      user = Map<String, dynamic>.from(body['user'] as Map);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', api.token!);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not reach the server: $e';
    }
  }

  Future<void> logout() async {
    try {
      await api.me().then((_) => api.token = api.token);
    } catch (_) {}
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}
