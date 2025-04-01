import 'package:flutter/material.dart';


class BankSpacing {
  
  static const double xxxs = 2;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
  static const double huge = 64;
  
  
  static const EdgeInsets paddingXXS = EdgeInsets.all(xxs);
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  
  
  static const EdgeInsets paddingHorizontalXS = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets paddingHorizontalSM = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMD = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLG = EdgeInsets.symmetric(horizontal: lg);
  
  
  static const EdgeInsets paddingVerticalXS = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVerticalSM = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMD = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLG = EdgeInsets.symmetric(vertical: lg);
  
  
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final double screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 360) {
      return baseSpacing * 0.8; 
    } else if (screenWidth > 600) {
      return baseSpacing * 1.25; 
    }
    
    return baseSpacing;
  }
}


class BankGrid {
  
  static const int columns = 12;
  static const double gutterWidth = BankSpacing.md;
  
  
  static double columnWidth(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double totalGutterWidth = gutterWidth * (columns - 1);
    return (screenWidth - totalGutterWidth) / columns;
  }
  
  
  static double getColumnSpan(BuildContext context, int span) {
    final double colWidth = columnWidth(context);
    final double gutters = gutterWidth * (span - 1);
    return colWidth * span + gutters;
  }
}
