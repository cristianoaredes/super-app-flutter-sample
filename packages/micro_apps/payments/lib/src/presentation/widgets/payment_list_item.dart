import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/payment.dart';

class PaymentListItem extends StatelessWidget {
  final Payment payment;
  final VoidCallback onTap;

  const PaymentListItem({
    Key? key,
    required this.payment,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildStatusIcon(payment.status),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.recipient,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(payment.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(payment.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusChip(payment.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(PaymentStatus status) {
    IconData iconData;
    Color iconColor;

    switch (status) {
      case PaymentStatus.pending:
        iconData = Icons.schedule;
        iconColor = Colors.orange;
        break;
      case PaymentStatus.processing:
        iconData = Icons.sync;
        iconColor = Colors.blue;
        break;
      case PaymentStatus.completed:
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case PaymentStatus.failed:
        iconData = Icons.error;
        iconColor = Colors.red;
        break;
      case PaymentStatus.cancelled:
        iconData = Icons.cancel;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
      ),
    );
  }

  Widget _buildStatusChip(PaymentStatus status) {
    String label;
    Color color;

    switch (status) {
      case PaymentStatus.pending:
        label = 'Pending';
        color = Colors.orange;
        break;
      case PaymentStatus.processing:
        label = 'Processing';
        color = Colors.blue;
        break;
      case PaymentStatus.completed:
        label = 'Completed';
        color = Colors.green;
        break;
      case PaymentStatus.failed:
        label = 'Failed';
        color = Colors.red;
        break;
      case PaymentStatus.cancelled:
        label = 'Cancelled';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
