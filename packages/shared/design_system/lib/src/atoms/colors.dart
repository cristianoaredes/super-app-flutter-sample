import 'package:flutter/material.dart';


class BankColors {
  
  static const MaterialColor brandPrimary = MaterialColor(
    0xFF006A6A, 
    <int, Color>{
      50: Color(0xFFE0F2F1),
      100: Color(0xFFB2DFDB),
      200: Color(0xFF80CBC4),
      300: Color(0xFF4DB6AC),
      400: Color(0xFF26A69A),
      500: Color(0xFF009688),
      600: Color(0xFF00897B),
      700: Color(0xFF00796B),
      800: Color(0xFF00695C),
      900: Color(0xFF004D40),
    },
  );

  
  static const MaterialColor brandSecondary = MaterialColor(
    0xFF03DAC6, 
    <int, Color>{
      50: Color(0xFFE0F7FA),
      100: Color(0xFFB2EBF2),
      200: Color(0xFF80DEEA),
      300: Color(0xFF4DD0E1),
      400: Color(0xFF26C6DA),
      500: Color(0xFF00BCD4),
      600: Color(0xFF00ACC1),
      700: Color(0xFF0097A7),
      800: Color(0xFF00838F),
      900: Color(0xFF006064),
    },
  );

  
  static const MaterialColor error = MaterialColor(
    0xFFB00020, 
    <int, Color>{
      50: Color(0xFFFFEBEE),
      100: Color(0xFFFFCDD2),
      200: Color(0xFFEF9A9A),
      300: Color(0xFFE57373),
      400: Color(0xFFEF5350),
      500: Color(0xFFF44336),
      600: Color(0xFFE53935),
      700: Color(0xFFD32F2F),
      800: Color(0xFFC62828),
      900: Color(0xFFB71C1C),
    },
  );

  
  static ColorScheme lightColorScheme(Color? seedColor) {
    final Color seed = seedColor ?? brandPrimary;
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
  }

  static ColorScheme darkColorScheme(Color? seedColor) {
    final Color seed = seedColor ?? brandPrimary;
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
  }

  
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
  
  
  static const Color positiveAmount = Color(0xFF4CAF50);
  static const Color negativeAmount = Color(0xFFE53935);
  static const Color pendingTransaction = Color(0xFFFFA000);
  static const Color processingTransaction = Color(0xFF03A9F4);
}
