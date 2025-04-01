import 'package:flutter/material.dart';

import '../../domain/entities/transaction.dart';
import 'transaction_item.dart';


class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  
  const TransactionList({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'Nenhuma transação encontrada',
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
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
          return TransactionItem(transaction: transaction);
        },
      ),
    );
  }
}
