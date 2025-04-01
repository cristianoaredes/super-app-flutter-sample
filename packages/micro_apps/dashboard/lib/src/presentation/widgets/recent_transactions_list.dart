import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/transaction_summary.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Card(
        elevation: 2.0,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Nenhuma transação recente',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2.0,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return _TransactionItem(transaction: transaction);
        },
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final isExpense = transaction.type == TransactionType.expense;

    Color amountColor;
    IconData typeIcon;

    if (isIncome) {
      amountColor = Colors.green;
      typeIcon = Icons.arrow_downward;
    } else if (isExpense) {
      amountColor = Colors.red;
      typeIcon = Icons.arrow_upward;
    } else {
      amountColor = Colors.blue;
      typeIcon = Icons.swap_horiz;
    }

    return ListTile(
      onTap: () {
        final navigationService = GetIt.instance<NavigationService>();
        navigationService.navigateTo(
          '/dashboard/transaction/:id',
          params: {'id': transaction.id},
        );
      },
      leading: Container(
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          color: amountColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          typeIcon,
          color: amountColor,
        ),
      ),
      title: Text(
        transaction.title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        transaction.date.toBR,
        style: TextStyle(
          fontSize: 12.0,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Text(
        transaction.amount.toBRL,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
    );
  }
}
