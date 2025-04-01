import 'package:flutter/material.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/transaction.dart';


class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  
  const TransactionItem({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = transaction.isIncoming;
    final statusColor = _getStatusColor(transaction.status);
    
    return ListTile(
      onTap: onTap,
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
        transaction.description,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transaction.category != null)
            Text(
              transaction.category!,
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
      isThreeLine: transaction.category != null,
    );
  }
  
  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.canceled:
        return Colors.grey;
    }
  }
  
  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pendente';
      case TransactionStatus.completed:
        return 'Concluída';
      case TransactionStatus.failed:
        return 'Falhou';
      case TransactionStatus.canceled:
        return 'Cancelada';
    }
  }
}
