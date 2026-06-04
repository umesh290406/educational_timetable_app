import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode get themeMode => ThemeMode.light;

  bool get isDarkMode => false;

  ThemeProvider();

  Future<void> toggleTheme() async {
    // No-op
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    // No-op
  }
}
