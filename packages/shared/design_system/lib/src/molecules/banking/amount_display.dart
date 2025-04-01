import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AmountType {
  positive,
  negative,
  neutral,
  pending,
  processing,
}

class AmountDisplay extends StatelessWidget {
  final double amount;
  final String currencyCode;
  final AmountType type;
  final bool showSign;
  final bool compact;

  const AmountDisplay({
    Key? key,
    required this.amount,
    this.currencyCode = 'BRL',
    this.type = AmountType.neutral,
    this.showSign = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color textColor;
    switch (type) {
      case AmountType.positive:
        textColor = const Color(0xFF4CAF50);
        break;
      case AmountType.negative:
        textColor = const Color(0xFFE53935);
        break;
      case AmountType.pending:
        textColor = const Color(0xFFFFA000);
        break;
      case AmountType.processing:
        textColor = const Color(0xFF03A9F4);
        break;
      case AmountType.neutral:
        textColor = colorScheme.onSurface;
        break;
    }

    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: currencyCode == 'BRL' ? 'R\$' : currencyCode,
      decimalDigits: compact ? 0 : 2,
    );

    final String formattedAmount;

    if (compact && amount.abs() >= 1000) {
      if (amount.abs() >= 1000000) {
        formattedAmount =
            formatter.format(amount / 1000000).replaceAll(',00', '') + 'M';
      } else {
        formattedAmount =
            formatter.format(amount / 1000).replaceAll(',00', '') + 'k';
      }
    } else {
      formattedAmount = formatter.format(amount);
    }

    final String displayText;
    if (showSign && amount > 0 && type == AmountType.positive) {
      displayText = '+$formattedAmount';
    } else {
      displayText = formattedAmount;
    }

    final String currencySymbol = formatter.currencySymbol;
    final String amountText = displayText.replaceFirst(currencySymbol, '');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          currencySymbol,
          style: textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          amountText,
          style: textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
