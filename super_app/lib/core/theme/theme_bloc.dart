import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeState.initial()) {
    on<ThemeChanged>(_onThemeChanged);
    on<ThemeUpdateRequested>(_onThemeUpdateRequested);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<ThemeResetRequested>(_onThemeResetRequested);
  }

  void _onThemeChanged(ThemeChanged event, Emitter<ThemeState> emit) {
    final themeMode = event.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    emit(state.copyWith(themeMode: themeMode));
  }

  void _onThemeUpdateRequested(
      ThemeUpdateRequested event, Emitter<ThemeState> emit) {
    emit(state.copyWith(
      lightTheme: event.lightTheme,
      darkTheme: event.darkTheme,
      seedColor: event.seedColor,
    ));
  }

  void _onThemeModeChanged(ThemeModeChanged event, Emitter<ThemeState> emit) {
    emit(state.copyWith(themeMode: event.mode));
  }

  void _onThemeResetRequested(
      ThemeResetRequested event, Emitter<ThemeState> emit) {
    emit(ThemeState.initial());
  }

  
  void updateSeedColor(Color color) {
    
    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: color,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: color,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    add(ThemeUpdateRequested(
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      seedColor: color,
    ));
  }

  
  void updateThemeMode(ThemeMode mode) {
    add(ThemeModeChanged(mode: mode));
  }

  
  void resetToDefaultTheme() {
    add(ThemeResetRequested());
  }
}
