import 'package:flutter/material.dart';


class BankElevation {
  
  static const double level0 = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 3.0;
  static const double level3 = 6.0;
  static const double level4 = 8.0;
  static const double level5 = 12.0;
  
  
  static List<BoxShadow> getShadowForElevation(double elevation, {Color? shadowColor}) {
    final Color color = shadowColor ?? Colors.black.withOpacity(0.1);
    
    if (elevation <= 0) {
      return [];
    } else if (elevation <= level1) {
      return [
        BoxShadow(
          color: color,
          blurRadius: 2.0,
          offset: const Offset(0, 1),
        ),
      ];
    } else if (elevation <= level2) {
      return [
        BoxShadow(
          color: color,
          blurRadius: 4.0,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (elevation <= level3) {
      return [
        BoxShadow(
          color: color,
          blurRadius: 8.0,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (elevation <= level4) {
      return [
        BoxShadow(
          color: color,
          blurRadius: 12.0,
          offset: const Offset(0, 6),
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: color,
          blurRadius: 16.0,
          offset: const Offset(0, 8),
        ),
      ];
    }
  }
}
