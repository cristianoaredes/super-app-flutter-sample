import 'package:flutter/material.dart';


class ThemeModeConverter {
  const ThemeModeConverter();

  ThemeMode fromJson(String json) {
    switch (json) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String toJson(ThemeMode themeMode) {
    return themeMode.toString().split('.').last;
  }
}
