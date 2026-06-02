import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {

  ThemeProvider._() {
    _loadPreference();
  }

  static final ThemeProvider instance =
  ThemeProvider._();

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark =>
      _themeMode == ThemeMode.dark;

  void _loadPreference() async {

    final prefs =
    await SharedPreferences.getInstance();

    final isDark =
        prefs.getBool('dark_mode') ?? false;

    _themeMode =
        isDark ? ThemeMode.dark : ThemeMode.light;

    notifyListeners();
  }

  Future<void> toggle() async {

    _themeMode = isDark
        ? ThemeMode.light
        : ThemeMode.dark;

    notifyListeners();

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setBool('dark_mode', isDark);
  }
}
