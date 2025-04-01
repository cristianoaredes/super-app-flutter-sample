import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFFD4AF37);
  static const _secondaryColor = Color(0xFFB8860B);
  static const _backgroundColor = Color(0xFF121212);
  static const _surfaceColor = Color(0xFF1E1E1E);
  static const _errorColor = Color(0xFFCF6679);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: _primaryColor,
      onPrimary: Colors.black,
      secondary: _secondaryColor,
      onSecondary: Colors.white,
      error: _errorColor,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      surfaceContainer: const Color(0xFFF5F5F5),
      onSurfaceVariant: Colors.black87,
      outline: Colors.black26,
      outlineVariant: Colors.black12,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: Colors.black,
      onInverseSurface: Colors.white,
      inversePrimary: _primaryColor.withOpacity(0.8),
      primaryContainer: _primaryColor.withOpacity(0.2),
      onPrimaryContainer: Colors.black,
      secondaryContainer: _secondaryColor.withOpacity(0.2),
      onSecondaryContainer: Colors.black,
      errorContainer: _errorColor.withOpacity(0.2),
      onErrorContainer: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: _primaryColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: _primaryColor),
      ),
      cardTheme: CardTheme(
        elevation: 4,
        shadowColor: _primaryColor.withOpacity(0.3),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _primaryColor.withOpacity(0.2), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: MaterialStateProperty.all(2),
          backgroundColor: MaterialStateProperty.all(_primaryColor),
          foregroundColor: MaterialStateProperty.all(Colors.black),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: MaterialStateProperty.all(
            const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(_primaryColor),
          side: MaterialStateProperty.all(
            BorderSide(color: _primaryColor, width: 1.5),
          ),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: MaterialStateProperty.all(
            const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(_primaryColor),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: MaterialStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        floatingLabelStyle: TextStyle(
          color: _primaryColor,
          fontWeight: FontWeight.bold,
        ),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIconColor: MaterialStateColor.resolveWith(
          (states) =>
              states.contains(MaterialState.focused)
                  ? _primaryColor
                  : Colors.grey.shade600,
        ),
        suffixIconColor: MaterialStateColor.resolveWith(
          (states) =>
              states.contains(MaterialState.focused)
                  ? _primaryColor
                  : Colors.grey.shade600,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            );
          }
          return TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);
        }),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _primaryColor,
      onPrimary: Colors.black,
      secondary: _secondaryColor,
      onSecondary: Colors.black,
      error: _errorColor,
      onError: Colors.black,
      background: _backgroundColor,
      onBackground: Colors.white,
      surface: _surfaceColor,
      onSurface: Colors.white,
      surfaceVariant: const Color(0xFF2C2C2C),
      onSurfaceVariant: Colors.white70,
      outline: Colors.white24,
      outlineVariant: Colors.white12,
      shadow: Colors.black,
      scrim: Colors.black87,
      inverseSurface: Colors.white,
      onInverseSurface: Colors.black,
      inversePrimary: _primaryColor.withOpacity(0.7),
      primaryContainer: _primaryColor.withOpacity(0.15),
      onPrimaryContainer: _primaryColor,
      secondaryContainer: _secondaryColor.withOpacity(0.15),
      onSecondaryContainer: _secondaryColor,
      errorContainer: _errorColor.withOpacity(0.15),
      onErrorContainer: _errorColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _backgroundColor,
        foregroundColor: _primaryColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: _primaryColor),
      ),
      cardTheme: CardTheme(
        elevation: 4,
        shadowColor: _primaryColor.withOpacity(0.5),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _primaryColor.withOpacity(0.3), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF1A1A1A),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: MaterialStateProperty.all(2),
          backgroundColor: MaterialStateProperty.all(_primaryColor),
          foregroundColor: MaterialStateProperty.all(Colors.black),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: MaterialStateProperty.all(
            const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(_primaryColor),
          side: MaterialStateProperty.all(
            BorderSide(color: _primaryColor, width: 1.5),
          ),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: MaterialStateProperty.all(
            const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(_primaryColor),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: MaterialStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: Colors.grey.shade400),
        floatingLabelStyle: TextStyle(
          color: _primaryColor,
          fontWeight: FontWeight.bold,
        ),
        hintStyle: TextStyle(color: Colors.grey.shade700),
        prefixIconColor: MaterialStateColor.resolveWith(
          (states) =>
              states.contains(MaterialState.focused)
                  ? _primaryColor
                  : Colors.grey.shade400,
        ),
        suffixIconColor: MaterialStateColor.resolveWith(
          (states) =>
              states.contains(MaterialState.focused)
                  ? _primaryColor
                  : Colors.grey.shade400,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            );
          }
          return TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);
        }),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
