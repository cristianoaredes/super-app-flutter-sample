import 'package:flutter/material.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/card_transaction.dart';


class TransactionItem extends StatelessWidget {
  final CardTransaction transaction;
  
  const TransactionItem({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isPurchase = transaction.type == CardTransactionType.purchase;
    final isPayment = transaction.type == CardTransactionType.payment;
    final isRefund = transaction.type == CardTransactionType.refund;
    final isWithdrawal = transaction.type == CardTransactionType.withdrawal;
    
    Color amountColor;
    IconData typeIcon;
    
    if (isPayment || isRefund) {
      amountColor = Colors.green;
      typeIcon = isPayment ? Icons.payment : Icons.replay;
    } else if (isPurchase || isWithdrawal) {
      amountColor = Colors.red;
      typeIcon = isPurchase ? Icons.shopping_cart : Icons.atm;
    } else {
      amountColor = Colors.blue;
      typeIcon = Icons.receipt;
    }
    
    return ListTile(
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
        transaction.description,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.merchant,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.grey.shade600,
            ),
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
              color: amountColor,
            ),
          ),
          const SizedBox(height: 4.0),
          _buildStatusChip(transaction.status),
        ],
      ),
      isThreeLine: true,
    );
  }
  
  Widget _buildStatusChip(CardTransactionStatus status) {
    Color backgroundColor;
    Color textColor = Colors.white;
    String label;
    
    switch (status) {
      case CardTransactionStatus.pending:
        backgroundColor = Colors.orange;
        label = 'Pendente';
        break;
      case CardTransactionStatus.approved:
        backgroundColor = Colors.green;
        label = 'Aprovada';
        break;
      case CardTransactionStatus.declined:
        backgroundColor = Colors.red;
        label = 'Recusada';
        break;
      case CardTransactionStatus.canceled:
        backgroundColor = Colors.grey;
        label = 'Cancelada';
        break;
      case CardTransactionStatus.refunded:
        backgroundColor = Colors.blue;
        label = 'Estornada';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
