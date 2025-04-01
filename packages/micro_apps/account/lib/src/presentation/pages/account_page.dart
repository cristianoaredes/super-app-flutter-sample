import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';

import '../bloc/account_bloc.dart';
import '../bloc/account_event.dart';
import '../bloc/account_state.dart';
import '../widgets/account_balance_card.dart';
import '../widgets/account_actions_card.dart';
import '../widgets/recent_transactions_card.dart';


class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<AccountBloc>().add(const LoadAccountEvent());
    context.read<AccountBloc>().add(const LoadAccountBalanceEvent());
    context.read<AccountBloc>().add(const LoadAccountStatementEvent());
  }

  void _navigateToAccountDetails() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/account/details');
  }

  void _navigateToAccountStatement() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/account/statement');
  }

  void _navigateToTransfer() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/account/transfer');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Conta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              BlocBuilder<AccountBloc, AccountState>(
                builder: (context, state) {
                  if (state is AccountLoadedState) {
                    final account = state.account;

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
                                  'Dados da Conta',
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: _navigateToAccountDetails,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Agência / Conta: ${account.formattedNumber}',
                              style: const TextStyle(
                                fontSize: 16.0,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'Titular: ${account.holderName}',
                              style: const TextStyle(
                                fontSize: 16.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state is AccountErrorState) {
                    return Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dados da Conta',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48.0,
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    'Erro ao carregar os dados: ${state.message}',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8.0),
                                  ElevatedButton(
                                    onPressed: () {
                                      context
                                          .read<AccountBloc>()
                                          .add(const LoadAccountEvent());
                                    },
                                    child: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return const Card(
                    elevation: 2.0,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16.0),

              
              BlocBuilder<AccountBloc, AccountState>(
                builder: (context, state) {
                  if (state is AccountBalanceLoadedState) {
                    return AccountBalanceCard(balance: state.balance);
                  }

                  if (state is AccountBalanceErrorState) {
                    return Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Saldo da Conta',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48.0,
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    'Erro ao carregar o saldo: ${state.message}',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8.0),
                                  ElevatedButton(
                                    onPressed: () {
                                      context
                                          .read<AccountBloc>()
                                          .add(const LoadAccountBalanceEvent());
                                    },
                                    child: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return const Card(
                    elevation: 2.0,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16.0),

              
              AccountActionsCard(
                onTransferTap: _navigateToTransfer,
                onStatementTap: _navigateToAccountStatement,
              ),

              const SizedBox(height: 16.0),

              
              BlocBuilder<AccountBloc, AccountState>(
                builder: (context, state) {
                  if (state is AccountStatementLoadedState) {
                    return RecentTransactionsCard(
                      transactions: state.statement.sortedTransactions,
                      onViewAllTap: _navigateToAccountStatement,
                    );
                  }

                  if (state is AccountStatementErrorState) {
                    return Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transações Recentes',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48.0,
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    'Erro ao carregar as transações: ${state.message}',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8.0),
                                  ElevatedButton(
                                    onPressed: () {
                                      context.read<AccountBloc>().add(
                                          const LoadAccountStatementEvent());
                                    },
                                    child: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return const Card(
                    elevation: 2.0,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
