import 'package:flutter/material.dart';

abstract class ThemeEvent {}

class ThemeChanged extends ThemeEvent {
  final bool isDarkMode;

  ThemeChanged({required this.isDarkMode});
}

class ThemeUpdateRequested extends ThemeEvent {
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final Color seedColor;

  ThemeUpdateRequested({
    required this.lightTheme,
    required this.darkTheme,
    required this.seedColor,
  });
}

class ThemeModeChanged extends ThemeEvent {
  final ThemeMode mode;

  ThemeModeChanged({required this.mode});
}

class ThemeResetRequested extends ThemeEvent {}
