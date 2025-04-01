import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_utils/shared_utils.dart';

import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_state.dart';


class AccountDetailsPage extends StatelessWidget {
  const AccountDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Conta'),
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoadedState) {
            final accountSummary = state.accountSummary;

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informações da Conta',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        _buildInfoRow('Agência', accountSummary.agency),
                        const Divider(),
                        _buildInfoRow('Conta', accountSummary.accountNumber),
                        const Divider(),
                        _buildInfoRow('Última Atualização',
                            accountSummary.lastUpdate.toBRDateTime),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Card(
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumo Financeiro',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        _buildFinancialRow(
                          'Saldo Atual',
                          accountSummary.balance.toBRL,
                          accountSummary.balance >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                        const Divider(),
                        _buildFinancialRow(
                          'Receitas',
                          accountSummary.income.toBRL,
                          Colors.green,
                        ),
                        const Divider(),
                        _buildFinancialRow(
                          'Despesas',
                          accountSummary.expenses.toBRL,
                          Colors.red,
                        ),
                        const Divider(),
                        _buildFinancialRow(
                          'Poupança',
                          accountSummary.savings.toBRL,
                          Colors.blue,
                        ),
                        const Divider(),
                        _buildFinancialRow(
                          'Investimentos',
                          accountSummary.investments.toBRL,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Card(
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ações',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildActionButton(
                              context,
                              'Extrato',
                              Icons.receipt_long,
                              () {
                                
                              },
                            ),
                            _buildActionButton(
                              context,
                              'Comprovantes',
                              Icons.description,
                              () {
                                
                              },
                            ),
                            _buildActionButton(
                              context,
                              'Configurações',
                              Icons.settings,
                              () {
                                
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.0),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Icon(
                icon,
                size: 32.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
