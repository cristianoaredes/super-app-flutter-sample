import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/account_summary.dart';


class AccountSummaryCard extends StatelessWidget {
  final AccountSummary accountSummary;

  const AccountSummaryCard({
    super.key,
    required this.accountSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      child: InkWell(
        onTap: () {
          
          final navigationService = GetIt.instance<NavigationService>();
          navigationService.navigateTo('/dashboard/account');
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saldo Disponível',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Ag. ${accountSummary.agency} | Conta ${accountSummary.accountNumber}',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                accountSummary.balance.toBRL,
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color:
                      accountSummary.balance >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16.0),
              const Divider(),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFinancialItem(
                    context,
                    'Receitas',
                    accountSummary.income.toBRL,
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                  _buildFinancialItem(
                    context,
                    'Despesas',
                    accountSummary.expenses.toBRL,
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                  _buildFinancialItem(
                    context,
                    'Investimentos',
                    accountSummary.investments.toBRL,
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20.0,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
