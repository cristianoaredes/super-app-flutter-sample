import 'package:flutter/material.dart';
import '../../atoms/spacing.dart';
import 'amount_display.dart';

enum TransactionCategory {
  income,
  expense,
  transfer,
  subscription,
  cashback,
  investment,
  loan,
  other,
}

class Transaction {
  final String id;
  final String title;
  final String? description;
  final double amount;
  final DateTime date;
  final TransactionCategory category;
  final String? imageUrl;
  final bool isPending;

  Transaction({
    required this.id,
    required this.title,
    this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.imageUrl,
    this.isPending = false,
  });
}

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({
    Key? key,
    required this.transaction,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    AmountType amountType;
    if (transaction.isPending) {
      amountType = AmountType.pending;
    } else if (transaction.category == TransactionCategory.income ||
        transaction.category == TransactionCategory.cashback) {
      amountType = AmountType.positive;
    } else if (transaction.category == TransactionCategory.expense ||
        transaction.category == TransactionCategory.subscription) {
      amountType = AmountType.negative;
    } else {
      amountType = AmountType.neutral;
    }

    IconData categoryIcon = _getCategoryIcon(transaction.category);

    return Card(
      margin: EdgeInsets.symmetric(
        vertical: BankSpacing.xs,
        horizontal: BankSpacing.sm,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(BankSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: transaction.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          transaction.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              categoryIcon,
                              color: colorScheme.primary,
                            );
                          },
                        ),
                      )
                    : Icon(
                        categoryIcon,
                        color: colorScheme.primary,
                      ),
              ),
              SizedBox(width: BankSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (transaction.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        transaction.description!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(transaction.date),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountDisplay(
                    amount: transaction.amount,
                    type: amountType,
                    showSign: true,
                  ),
                  if (transaction.isPending) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: BankSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Pendente',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.income:
        return Icons.arrow_downward;
      case TransactionCategory.expense:
        return Icons.arrow_upward;
      case TransactionCategory.transfer:
        return Icons.swap_horiz;
      case TransactionCategory.subscription:
        return Icons.repeat;
      case TransactionCategory.cashback:
        return Icons.redeem;
      case TransactionCategory.investment:
        return Icons.trending_up;
      case TransactionCategory.loan:
        return Icons.account_balance;
      case TransactionCategory.other:
        return Icons.receipt;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hoje, ${_formatTime(date)}';
    } else if (dateOnly == yesterday) {
      return 'Ontem, ${_formatTime(date)}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}, ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
