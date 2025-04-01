import 'package:flutter/material.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/account_statement.dart';


class StatementSummary extends StatelessWidget {
  final AccountStatement statement;
  
  const StatementSummary({
    super.key,
    required this.statement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSummaryRow(
          'Saldo Inicial',
          statement.initialBalance.toBRL,
          statement.initialBalance >= 0 ? Colors.blue : Colors.red,
        ),
        const SizedBox(height: 8.0),
        _buildSummaryRow(
          'Total Entradas',
          statement.totalCredits.toBRL,
          Colors.green,
        ),
        const SizedBox(height: 8.0),
        _buildSummaryRow(
          'Total Saídas',
          statement.totalDebits.toBRL,
          Colors.red,
        ),
        const Divider(height: 24.0),
        _buildSummaryRow(
          'Saldo Final',
          statement.finalBalance.toBRL,
          statement.finalBalance >= 0 ? Colors.green : Colors.red,
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
