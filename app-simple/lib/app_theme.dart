import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark mode with persistence. Defaults to the system setting
/// until the user picks explicitly with the sun/moon toggle.
class AppTheme extends ChangeNotifier {
  AppTheme();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('theme_mode');
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {}
    notifyListeners();
  }

  bool effectiveDark(BuildContext context) {
    if (_mode == ThemeMode.light) return false;
    if (_mode == ThemeMode.dark) return true;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Future<void> toggle(BuildContext context) async {
    _mode = effectiveDark(context) ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'theme_mode',
        _mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
    notifyListeners();
  }
}
