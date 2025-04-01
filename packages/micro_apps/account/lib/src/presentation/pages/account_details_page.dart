import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/account.dart';
import '../bloc/account_bloc.dart';
import '../bloc/account_event.dart';
import '../bloc/account_state.dart';


class AccountDetailsPage extends StatefulWidget {
  const AccountDetailsPage({super.key});

  @override
  State<AccountDetailsPage> createState() => _AccountDetailsPageState();
}

class _AccountDetailsPageState extends State<AccountDetailsPage> {
  @override
  void initState() {
    super.initState();
    
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _getAccountTypeName(AccountType type) {
    switch (type) {
      case AccountType.checking:
        return 'Conta Corrente';
      case AccountType.savings:
        return 'Conta Poupança';
      case AccountType.salary:
        return 'Conta Salário';
      case AccountType.investment:
        return 'Conta Investimento';
      default:
        return 'Conta';
    }
  }

  String _getAccountStatusName(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return 'Ativa';
      case AccountStatus.inactive:
        return 'Inativa';
      case AccountStatus.blocked:
        return 'Bloqueada';
      case AccountStatus.closed:
        return 'Encerrada';
      default:
        return 'Desconhecido';
    }
  }

  Color _getAccountStatusColor(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return Colors.green;
      case AccountStatus.inactive:
        return Colors.orange;
      case AccountStatus.blocked:
        return Colors.red;
      case AccountStatus.closed:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Conta'),
      ),
      body: BlocProvider<AccountBloc>(
        create: (context) => GetIt.instance<AccountBloc>(),
        child: Builder(builder: (context) {
          
          context.read<AccountBloc>().add(const LoadAccountEvent());

          return BlocBuilder<AccountBloc, AccountState>(
            builder: (context, state) {
              if (state is AccountLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (state is AccountLoadedState) {
                final account = state.account;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 2.0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Informações da Conta',
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 4.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _getAccountStatusColor(account.status)
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                    child: Text(
                                      _getAccountStatusName(account.status),
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.bold,
                                        color: _getAccountStatusColor(
                                            account.status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16.0),
                              _buildInfoRow('Tipo de Conta',
                                  _getAccountTypeName(account.type)),
                              const Divider(),
                              _buildInfoRow('Agência', account.agency),
                              const Divider(),
                              _buildInfoRow('Conta', account.number),
                              const Divider(),
                              _buildInfoRow('Titular', account.holderName),
                              const Divider(),
                              _buildInfoRow('CPF/CNPJ', account.holderDocument),
                              const Divider(),
                              _buildInfoRow('Data de Abertura',
                                  _formatDate(account.openingDate)),
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
                                'Informações Adicionais',
                                style: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              const Text(
                                'Sua conta está protegida pelo Fundo Garantidor de Créditos (FGC) até o limite de R\$ 250.000,00 por CPF/CNPJ.',
                                style: TextStyle(
                                  fontSize: 14.0,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              const Text(
                                'Para mais informações sobre sua conta, entre em contato com o nosso atendimento.',
                                style: TextStyle(
                                  fontSize: 14.0,
                                ),
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
                                'Atendimento',
                                style: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              _buildContactRow(
                                Icons.phone,
                                'Central de Atendimento',
                                '0800 123 4567',
                              ),
                              const SizedBox(height: 8.0),
                              _buildContactRow(
                                Icons.headset_mic,
                                'SAC',
                                '0800 765 4321',
                              ),
                              const SizedBox(height: 8.0),
                              _buildContactRow(
                                Icons.support_agent,
                                'Ouvidoria',
                                '0800 987 6543',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (state is AccountErrorState) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64.0,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'Erro ao carregar os dados da conta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24.0),
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<AccountBloc>()
                              .add(const LoadAccountEvent());
                        },
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          );
        }),
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

  Widget _buildContactRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
