import 'package:flutter/material.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/pix_transaction.dart';


class PixTransactionList extends StatelessWidget {
  final List<PixTransaction> transactions;
  final int? maxItems;

  const PixTransactionList({
    super.key,
    required this.transactions,
    this.maxItems,
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

    
    final sortedTransactions = List<PixTransaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    
    final displayedTransactions =
        maxItems != null && maxItems! < sortedTransactions.length
            ? sortedTransactions.take(maxItems!).toList()
            : sortedTransactions;

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedTransactions.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final transaction = displayedTransactions[index];
            return _TransactionItem(transaction: transaction);
          },
        ),
        if (maxItems != null && maxItems! < sortedTransactions.length) ...[
          const Divider(),
          TextButton(
            onPressed: () {
              
            },
            child: const Text('Ver todas as transações'),
          ),
        ],
      ],
    );
  }
}


class _TransactionItem extends StatelessWidget {
  final PixTransaction transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncoming = transaction.isIncoming;
    final statusColor = _getStatusColor(transaction.status);

    return ListTile(
      onTap: () {
        final navigationService = GetIt.instance<NavigationService>();
        navigationService.navigateTo(
          '/pix/transaction/:id',
          params: {'id': transaction.id},
        );
      },
      leading: Container(
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          color: (isIncoming ? Colors.green : Colors.red).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncoming ? Colors.green : Colors.red,
        ),
      ),
      title: Text(
        isIncoming
            ? 'Recebido de ${transaction.sender.name}'
            : 'Enviado para ${transaction.receiver.name}',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.description,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            transaction.date.toBRDateTime,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            transaction.amount.toBRL,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncoming ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 4.0),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 2.0,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Text(
              _getStatusText(transaction.status),
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }

  Color _getStatusColor(PixTransactionStatus status) {
    switch (status) {
      case PixTransactionStatus.pending:
        return Colors.orange;
      case PixTransactionStatus.completed:
        return Colors.green;
      case PixTransactionStatus.failed:
        return Colors.red;
      case PixTransactionStatus.returned:
        return Colors.blue;
    }
  }

  String _getStatusText(PixTransactionStatus status) {
    switch (status) {
      case PixTransactionStatus.pending:
        return 'Pendente';
      case PixTransactionStatus.completed:
        return 'Concluído';
      case PixTransactionStatus.failed:
        return 'Falhou';
      case PixTransactionStatus.returned:
        return 'Devolvido';
    }
  }
}
