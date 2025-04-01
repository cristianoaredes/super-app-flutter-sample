import 'package:flutter/material.dart';
import '../../atoms/spacing.dart';

enum BankButtonSize {
  small,
  medium,
  large,
}

enum BankButtonImportance {
  primary,
  secondary,
  tertiary,
}

class BankButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BankButtonSize size;
  final BankButtonImportance importance;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  
  const BankButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.size = BankButtonSize.medium,
    this.importance = BankButtonImportance.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    
    double height;
    double horizontalPadding;
    TextStyle textStyle;
    
    switch (size) {
      case BankButtonSize.small:
        height = 32;
        horizontalPadding = BankSpacing.sm;
        textStyle = textTheme.labelMedium!;
        break;
      case BankButtonSize.medium:
        height = 40;
        horizontalPadding = BankSpacing.md;
        textStyle = textTheme.labelLarge!;
        break;
      case BankButtonSize.large:
        height = 48;
        horizontalPadding = BankSpacing.lg;
        textStyle = textTheme.titleSmall!;
        break;
    }
    
    
    ButtonStyle buttonStyle;
    
    switch (importance) {
      case BankButtonImportance.primary:
        buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 1.0,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        );
        break;
      case BankButtonImportance.secondary:
        buttonStyle = OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        );
        break;
      case BankButtonImportance.tertiary:
        buttonStyle = TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        );
        break;
    }
    
    
    Widget child;
    
    if (isLoading) {
      child = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: importance == BankButtonImportance.primary
              ? colorScheme.onPrimary
              : colorScheme.primary,
        ),
      );
    } else {
      child = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 18),
            SizedBox(width: 8),
          ],
          Text(label, style: textStyle),
          if (trailingIcon != null) ...[
            SizedBox(width: 8),
            Icon(trailingIcon, size: 18),
          ],
        ],
      );
    }
    
    
    Widget button;
    
    switch (importance) {
      case BankButtonImportance.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
        break;
      case BankButtonImportance.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
        break;
      case BankButtonImportance.tertiary:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
        break;
    }
    
    return SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : null,
      child: button,
    );
  }
}
