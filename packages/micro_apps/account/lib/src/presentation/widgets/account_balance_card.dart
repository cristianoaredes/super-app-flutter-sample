import 'package:flutter/material.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/account_balance.dart';


class AccountBalanceCard extends StatefulWidget {
  final AccountBalance balance;
  
  const AccountBalanceCard({
    super.key,
    required this.balance,
  });

  @override
  State<AccountBalanceCard> createState() => _AccountBalanceCardState();
}

class _AccountBalanceCardState extends State<AccountBalanceCard> {
  bool _isBalanceVisible = true;
  
  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final balance = widget.balance;
    
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
                  'Saldo da Conta',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: _toggleBalanceVisibility,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            _buildBalanceRow(
              'Saldo Disponível',
              _isBalanceVisible ? balance.available.toBRL : '••••••',
              balance.isNegative ? Colors.red : Colors.green,
              isBold: true,
            ),
            const SizedBox(height: 8.0),
            _buildBalanceRow(
              'Limite de Cheque Especial',
              _isBalanceVisible ? balance.overdraftLimit.toBRL : '••••••',
              Colors.blue,
            ),
            if (balance.isUsingOverdraft) ...[
              const SizedBox(height: 8.0),
              _buildBalanceRow(
                'Cheque Especial Utilizado',
                _isBalanceVisible ? balance.overdraftUsed.toBRL : '••••••',
                Colors.orange,
              ),
            ],
            if (balance.blocked > 0) ...[
              const SizedBox(height: 8.0),
              _buildBalanceRow(
                'Valor Bloqueado',
                _isBalanceVisible ? balance.blocked.toBRL : '••••••',
                Colors.red,
              ),
            ],
            const Divider(height: 24.0),
            _buildBalanceRow(
              'Saldo Total',
              _isBalanceVisible ? balance.total.toBRL : '••••••',
              balance.total >= 0 ? Colors.green : Colors.red,
              isBold: true,
            ),
            const SizedBox(height: 8.0),
            Text(
              'Atualizado em: ${balance.updatedAt.toBRDateTime}',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBalanceRow(
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
