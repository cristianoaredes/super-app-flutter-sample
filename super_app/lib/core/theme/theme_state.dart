import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

class ThemeState extends Equatable {
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;
  final Color seedColor;

  const ThemeState({
    required this.lightTheme,
    required this.darkTheme,
    required this.themeMode,
    required this.seedColor,
  });

  factory ThemeState.initial() {
    return ThemeState(
      lightTheme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, 
      seedColor: const Color(0xFFD4AF37), 
    );
  }

  ThemeState copyWith({
    ThemeData? lightTheme,
    ThemeData? darkTheme,
    ThemeMode? themeMode,
    Color? seedColor,
  }) {
    return ThemeState(
      lightTheme: lightTheme ?? this.lightTheme,
      darkTheme: darkTheme ?? this.darkTheme,
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
    );
  }

  @override
  List<Object> get props => [lightTheme, darkTheme, themeMode, seedColor];
}
