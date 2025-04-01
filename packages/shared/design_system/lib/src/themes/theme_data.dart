import 'package:flutter/material.dart';
import '../atoms/colors.dart';
import '../atoms/typography.dart';
import 'theme_extensions.dart';


class BankTheme {
  
  static ThemeData lightTheme = _buildLightTheme();
  static ThemeData darkTheme = _buildDarkTheme();
  
  
  static ThemeData generateThemeFromSeed(Color seedColor, {bool isDark = false}) {
    final ColorScheme colorScheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          )
        : ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
          );
    
    return isDark
        ? _buildTheme(colorScheme, isDark: true)
        : _buildTheme(colorScheme, isDark: false);
  }
  
  
  static ThemeData _buildLightTheme() {
    final ColorScheme colorScheme = BankColors.lightColorScheme(null);
    return _buildTheme(colorScheme, isDark: false);
  }
  
  
  static ThemeData _buildDarkTheme() {
    final ColorScheme colorScheme = BankColors.darkColorScheme(null);
    return _buildTheme(colorScheme, isDark: true);
  }
  
  
  static ThemeData _buildTheme(ColorScheme colorScheme, {required bool isDark}) {
    final TextTheme textTheme = BankTypography.textTheme;
    
    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: isDark ? Brightness.dark : Brightness.light,
      
      
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      
      
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceVariant,
        foregroundColor: colorScheme.onSurfaceVariant,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.outline,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.outline,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2.0,
          ),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.error,
        ),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        deleteIconColor: colorScheme.onSurface,
        disabledColor: colorScheme.surfaceVariant,
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colorScheme.outline,
            width: 1.0,
          ),
        ),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
      ),
      
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(
              color: colorScheme.primary,
            );
          }
          return IconThemeData(
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),
      
      tabBarTheme: TabBarTheme(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2.0,
          ),
        ),
      ),
    );
    
    
    return baseTheme.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        FormThemeExtension.light(baseTheme),
        AnimationThemeExtension.standard(),
        BankingThemeExtension.light(baseTheme),
      ],
    );
  }
}
