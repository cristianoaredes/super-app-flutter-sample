import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../atoms/colors.dart';
import 'theme_data.dart';


class ThemeState {
  final ThemeMode themeMode;
  final Color seedColor;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const ThemeState({
    required this.themeMode,
    required this.seedColor,
    required this.lightTheme,
    required this.darkTheme,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    Color? seedColor,
    ThemeData? lightTheme,
    ThemeData? darkTheme,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      lightTheme: lightTheme ?? this.lightTheme,
      darkTheme: darkTheme ?? this.darkTheme,
    );
  }
}


class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit()
      : super(
          ThemeState(
            themeMode: ThemeMode.system,
            seedColor: BankColors.brandPrimary,
            lightTheme: BankTheme.lightTheme,
            darkTheme: BankTheme.darkTheme,
          ),
        );

  
  void toggleTheme() {
    final newThemeMode =
        state.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

    emit(state.copyWith(themeMode: newThemeMode));
  }

  
  void setThemeMode(ThemeMode themeMode) {
    emit(state.copyWith(themeMode: themeMode));
  }

  
  void setSeedColor(Color color) {
    final lightTheme = BankTheme.generateThemeFromSeed(color, isDark: false);
    final darkTheme = BankTheme.generateThemeFromSeed(color, isDark: true);

    emit(state.copyWith(
      seedColor: color,
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      
      themeMode: ThemeMode.light,
    ));
  }

  
  void resetToDefaultTheme() {
    emit(ThemeState(
      themeMode: ThemeMode.system,
      seedColor: BankColors.brandPrimary,
      lightTheme: BankTheme.lightTheme,
      darkTheme: BankTheme.darkTheme,
    ));
  }
}
