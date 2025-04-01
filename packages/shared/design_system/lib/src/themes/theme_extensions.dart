import 'package:flutter/material.dart';


class FormThemeExtension extends ThemeExtension<FormThemeExtension> {
  final EdgeInsets fieldSpacing;
  final EdgeInsets sectionSpacing;
  final TextStyle? labelStyle;
  final TextStyle? helperStyle;
  final TextStyle? errorStyle;
  
  FormThemeExtension({
    required this.fieldSpacing,
    required this.sectionSpacing,
    this.labelStyle,
    this.helperStyle,
    this.errorStyle,
  });
  
  @override
  ThemeExtension<FormThemeExtension> copyWith({
    EdgeInsets? fieldSpacing,
    EdgeInsets? sectionSpacing,
    TextStyle? labelStyle,
    TextStyle? helperStyle,
    TextStyle? errorStyle,
  }) {
    return FormThemeExtension(
      fieldSpacing: fieldSpacing ?? this.fieldSpacing,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
      labelStyle: labelStyle ?? this.labelStyle,
      helperStyle: helperStyle ?? this.helperStyle,
      errorStyle: errorStyle ?? this.errorStyle,
    );
  }
  
  @override
  ThemeExtension<FormThemeExtension> lerp(
    covariant ThemeExtension<FormThemeExtension>? other, 
    double t,
  ) {
    if (other is! FormThemeExtension) {
      return this;
    }
    
    return FormThemeExtension(
      fieldSpacing: EdgeInsets.lerp(fieldSpacing, other.fieldSpacing, t)!,
      sectionSpacing: EdgeInsets.lerp(sectionSpacing, other.sectionSpacing, t)!,
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      helperStyle: TextStyle.lerp(helperStyle, other.helperStyle, t),
      errorStyle: TextStyle.lerp(errorStyle, other.errorStyle, t),
    );
  }
  
  
  static FormThemeExtension light(ThemeData theme) {
    return FormThemeExtension(
      fieldSpacing: const EdgeInsets.only(bottom: 16),
      sectionSpacing: const EdgeInsets.only(bottom: 24, top: 8),
      labelStyle: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      helperStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      errorStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
  
  
  static FormThemeExtension dark(ThemeData theme) {
    return FormThemeExtension(
      fieldSpacing: const EdgeInsets.only(bottom: 16),
      sectionSpacing: const EdgeInsets.only(bottom: 24, top: 8),
      labelStyle: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      helperStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      errorStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}


class AnimationThemeExtension extends ThemeExtension<AnimationThemeExtension> {
  final Duration shortDuration;
  final Duration mediumDuration;
  final Duration longDuration;
  final Curve defaultCurve;
  final Curve emphasizedCurve;
  
  AnimationThemeExtension({
    required this.shortDuration,
    required this.mediumDuration,
    required this.longDuration,
    required this.defaultCurve,
    required this.emphasizedCurve,
  });
  
  @override
  ThemeExtension<AnimationThemeExtension> copyWith({
    Duration? shortDuration,
    Duration? mediumDuration,
    Duration? longDuration,
    Curve? defaultCurve,
    Curve? emphasizedCurve,
  }) {
    return AnimationThemeExtension(
      shortDuration: shortDuration ?? this.shortDuration,
      mediumDuration: mediumDuration ?? this.mediumDuration,
      longDuration: longDuration ?? this.longDuration,
      defaultCurve: defaultCurve ?? this.defaultCurve,
      emphasizedCurve: emphasizedCurve ?? this.emphasizedCurve,
    );
  }
  
  @override
  ThemeExtension<AnimationThemeExtension> lerp(
    covariant ThemeExtension<AnimationThemeExtension>? other, 
    double t,
  ) {
    if (other is! AnimationThemeExtension) {
      return this;
    }
    
    
    return this;
  }
  
  
  static AnimationThemeExtension standard() {
    return AnimationThemeExtension(
      shortDuration: const Duration(milliseconds: 100),
      mediumDuration: const Duration(milliseconds: 250),
      longDuration: const Duration(milliseconds: 500),
      defaultCurve: Curves.easeInOut,
      emphasizedCurve: Curves.easeOutCubic,
    );
  }
}


class BankingThemeExtension extends ThemeExtension<BankingThemeExtension> {
  final Color positiveAmountColor;
  final Color negativeAmountColor;
  final Color pendingColor;
  final Color processingColor;
  final TextStyle? currencyStyle;
  final TextStyle? amountStyle;
  
  BankingThemeExtension({
    required this.positiveAmountColor,
    required this.negativeAmountColor,
    required this.pendingColor,
    required this.processingColor,
    this.currencyStyle,
    this.amountStyle,
  });
  
  @override
  ThemeExtension<BankingThemeExtension> copyWith({
    Color? positiveAmountColor,
    Color? negativeAmountColor,
    Color? pendingColor,
    Color? processingColor,
    TextStyle? currencyStyle,
    TextStyle? amountStyle,
  }) {
    return BankingThemeExtension(
      positiveAmountColor: positiveAmountColor ?? this.positiveAmountColor,
      negativeAmountColor: negativeAmountColor ?? this.negativeAmountColor,
      pendingColor: pendingColor ?? this.pendingColor,
      processingColor: processingColor ?? this.processingColor,
      currencyStyle: currencyStyle ?? this.currencyStyle,
      amountStyle: amountStyle ?? this.amountStyle,
    );
  }
  
  @override
  ThemeExtension<BankingThemeExtension> lerp(
    covariant ThemeExtension<BankingThemeExtension>? other, 
    double t,
  ) {
    if (other is! BankingThemeExtension) {
      return this;
    }
    
    return BankingThemeExtension(
      positiveAmountColor: Color.lerp(positiveAmountColor, other.positiveAmountColor, t)!,
      negativeAmountColor: Color.lerp(negativeAmountColor, other.negativeAmountColor, t)!,
      pendingColor: Color.lerp(pendingColor, other.pendingColor, t)!,
      processingColor: Color.lerp(processingColor, other.processingColor, t)!,
      currencyStyle: TextStyle.lerp(currencyStyle, other.currencyStyle, t),
      amountStyle: TextStyle.lerp(amountStyle, other.amountStyle, t),
    );
  }
  
  
  static BankingThemeExtension light(ThemeData theme) {
    return BankingThemeExtension(
      positiveAmountColor: const Color(0xFF4CAF50), 
      negativeAmountColor: const Color(0xFFE53935), 
      pendingColor: const Color(0xFFFFA000), 
      processingColor: const Color(0xFF03A9F4), 
      currencyStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurface.withOpacity(0.8),
      ),
      amountStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }
  
  
  static BankingThemeExtension dark(ThemeData theme) {
    return BankingThemeExtension(
      positiveAmountColor: const Color(0xFF81C784), 
      negativeAmountColor: const Color(0xFFEF5350), 
      pendingColor: const Color(0xFFFFCA28), 
      processingColor: const Color(0xFF4FC3F7), 
      currencyStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurface.withOpacity(0.8),
      ),
      amountStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }
}
