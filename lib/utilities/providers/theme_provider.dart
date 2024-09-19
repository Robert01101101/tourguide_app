// theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/ui/tourguide_theme.dart';
import 'package:tourguide_app/utilities/custom_import.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeModeWithString(String themeModeString) async {
    _themeMode = _stringToThemeMode(themeModeString);
    await setThemeMode(_themeMode);
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    logger.i('ThemeProvider.setThemeMode() - themeMode=$_themeMode');
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeMode.toString());
  }

  Future<void> _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? themeModeString = prefs.getString(_themeModeKey);
    if (themeModeString != null) {
      _themeMode = _stringToThemeMode(themeModeString);
    } else {
      _themeMode = ThemeMode.system; // Default to system theme
    }
    notifyListeners();
  }

  ThemeMode _stringToThemeMode(String themeModeString) {
    switch (themeModeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }
}
