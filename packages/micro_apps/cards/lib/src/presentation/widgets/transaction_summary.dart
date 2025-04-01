import 'package:flutter/material.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/card_statement.dart';


class TransactionSummary extends StatelessWidget {
  final CardStatement statement;
  
  const TransactionSummary({
    super.key,
    required this.statement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSummaryRow(
          'Total Gasto',
          statement.totalSpent.toBRL,
          Colors.red,
        ),
        const SizedBox(height: 8.0),
        _buildSummaryRow(
          'Total Pagamentos',
          statement.totalPayments.toBRL,
          Colors.green,
        ),
        const SizedBox(height: 8.0),
        _buildSummaryRow(
          'Total Estornos',
          statement.totalRefunds.toBRL,
          Colors.blue,
        ),
        const SizedBox(height: 8.0),
        _buildSummaryRow(
          'Total Taxas',
          statement.totalFees.toBRL,
          Colors.orange,
        ),
        const Divider(height: 24.0),
        _buildSummaryRow(
          'Saldo',
          statement.balance.toBRL,
          statement.balance >= 0 ? Colors.green : Colors.red,
          isBold: true,
        ),
      ],
    );
  }
  
  Widget _buildSummaryRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
