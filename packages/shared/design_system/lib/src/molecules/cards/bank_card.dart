import 'package:flutter/material.dart';
import '../../atoms/spacing.dart';
import '../../atoms/elevation.dart';

enum BankCardType {
  elevated,
  outlined,
  filled,
}

class BankCard extends StatelessWidget {
  final Widget child;
  final BankCardType type;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  
  const BankCard({
    Key? key,
    required this.child,
    this.type = BankCardType.elevated,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    
    Color bgColor;
    BoxBorder? border;
    List<BoxShadow>? boxShadow;
    
    switch (type) {
      case BankCardType.elevated:
        bgColor = backgroundColor ?? colorScheme.surface;
        boxShadow = BankElevation.getShadowForElevation(BankElevation.level2);
        break;
      case BankCardType.outlined:
        bgColor = backgroundColor ?? colorScheme.surface;
        border = Border.all(
          color: colorScheme.outline,
          width: 1.0,
        );
        break;
      case BankCardType.filled:
        bgColor = backgroundColor ?? colorScheme.surfaceVariant;
        break;
    }
    
    final cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? EdgeInsets.all(BankSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: cardContent,
      );
    }
    
    return cardContent;
  }
}
