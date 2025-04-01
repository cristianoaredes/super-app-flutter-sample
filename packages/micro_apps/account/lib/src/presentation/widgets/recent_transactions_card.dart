import 'package:flutter/material.dart';

import '../../domain/entities/transaction.dart';
import 'transaction_item.dart';


class RecentTransactionsCard extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback onViewAllTap;
  final int maxItems;
  
  const RecentTransactionsCard({
    super.key,
    required this.transactions,
    required this.onViewAllTap,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    final displayedTransactions = transactions.length > maxItems
        ? transactions.sublist(0, maxItems)
        : transactions;
    
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transações Recentes',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: onViewAllTap,
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'Nenhuma transação encontrada',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedTransactions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final transaction = displayedTransactions[index];
                  return TransactionItem(transaction: transaction);
                },
              ),
          ],
        ),
      ),
    );
  }
}
