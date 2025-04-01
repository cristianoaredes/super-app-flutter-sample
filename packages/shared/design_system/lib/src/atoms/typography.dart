import 'package:flutter/material.dart';


class BankTypography {
  
  static const String fontFamily = 'Roboto';

  
  static const double _baseDisplaySize = 36;
  static const double _baseHeadlineSize = 24;
  static const double _baseTitleSize = 18;
  static const double _baseBodySize = 14;
  static const double _baseLabelSize = 12;

  
  static const double _smallScreenFactor = 0.9;
  static const double _largeScreenFactor = 1.1;

  
  static TextTheme get textTheme {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseDisplaySize * 1.25,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseDisplaySize,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseDisplaySize * 0.875,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseHeadlineSize * 1.25,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseHeadlineSize,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseHeadlineSize * 0.875,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseTitleSize * 1.25,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseTitleSize,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseTitleSize * 0.875,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseBodySize * 1.125,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseBodySize,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseBodySize * 0.875,
        fontWeight: FontWeight.normal,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseLabelSize * 1.125,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseLabelSize,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: _baseLabelSize * 0.875,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  
  static TextTheme getResponsiveTextTheme(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    
    double scaleFactor = 1.0;
    if (screenWidth < 360) {
      scaleFactor = _smallScreenFactor;
    } else if (screenWidth > 600) {
      scaleFactor = _largeScreenFactor;
    }

    return textTheme.apply(
      fontSizeFactor: scaleFactor,
    );
  }
}
