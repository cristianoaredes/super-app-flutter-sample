import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/pix_key.dart';
import '../bloc/pix_bloc.dart';
import '../bloc/pix_event.dart';
import '../bloc/pix_state.dart';
import '../widgets/pix_action_card.dart';
import '../widgets/pix_transaction_list.dart';

class PixHomePage extends StatefulWidget {
  const PixHomePage({super.key});

  @override
  State<PixHomePage> createState() => _PixHomePageState();
}

class _PixHomePageState extends State<PixHomePage>
    with AutomaticKeepAliveClientMixin {
  bool _hasAttemptedLoad = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasAttemptedLoad) {
      _loadDataSafely();
      _hasAttemptedLoad = true;
    }
  }

  void _loadDataSafely() {
    try {
      if (mounted) {
        final bloc = context.read<PixBloc>();
        // Verificar acesso ao state para garantir que o bloc está em um estado válido
        bloc.state;

        // Se chegou aqui, o bloc está em um estado válido
        bloc.add(const LoadPixKeysEvent());
        bloc.add(const LoadPixTransactionsEvent());
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do Pix: $e');
      // Se falhou, podemos tentar navegar para o dashboard para forçar a reinicialização
      try {
        final navigationService = GetIt.instance<NavigationService>();
        navigationService.navigateTo('/dashboard');
      } catch (navigateError) {
        debugPrint('Erro ao tentar voltar ao dashboard: $navigateError');
      }
    }
  }

  void _navigateToPixKeys() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/pix/keys');
  }

  void _navigateToSendPix() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/pix/send');
  }

  void _navigateToReceivePix() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/pix/receive');
  }

  void _navigateToScanQrCode() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/pix/scan');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessário para AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataSafely,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadDataSafely();
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
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
                      const Text(
                        'Ações Pix',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          PixActionCard(
                            icon: Icons.send,
                            title: 'Enviar',
                            onTap: _navigateToSendPix,
                          ),
                          PixActionCard(
                            icon: Icons.qr_code,
                            title: 'Receber',
                            onTap: _navigateToReceivePix,
                          ),
                          PixActionCard(
                            icon: Icons.qr_code_scanner,
                            title: 'Ler QR Code',
                            onTap: _navigateToScanQrCode,
                          ),
                          PixActionCard(
                            icon: Icons.vpn_key,
                            title: 'Minhas Chaves',
                            onTap: _navigateToPixKeys,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              BlocBuilder<PixBloc, PixState>(
                builder: (context, state) {
                  // Verificar se o estado é um PixCompositeState
                  if (state is PixCompositeState) {
                    final keysState = state.keysState;
                    final transactionsState = state.transactionsState;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card das Chaves Pix
                        if (keysState is PixKeysLoadingState)
                          const Card(
                            elevation: 2.0,
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          )
                        else if (keysState is PixKeysLoadedState)
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
                                        'Minhas Chaves',
                                        style: TextStyle(
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _navigateToPixKeys,
                                        child: const Text('Ver todas'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8.0),
                                  if (keysState.keys.isEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16.0),
                                      child: Center(
                                        child: Text(
                                          'Você ainda não possui chaves Pix cadastradas',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: keysState.keys.length > 3
                                          ? 3
                                          : keysState.keys.length,
                                      itemBuilder: (context, index) {
                                        final key = keysState.keys[index];
                                        return ListTile(
                                          title: Text(key.value),
                                          subtitle: Text(key.type.toString()),
                                          leading: _getPixKeyTypeIcon(key.type),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          )
                        else if (keysState is PixKeysErrorState)
                          Card(
                            elevation: 2.0,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'Erro ao carregar chaves: ${keysState.message}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 24.0),

                        // Card das Transações
                        if (transactionsState is PixTransactionsLoadingState)
                          const Card(
                            elevation: 2.0,
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          )
                        else if (transactionsState
                            is PixTransactionsLoadedState)
                          Card(
                            elevation: 2.0,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Histórico de Transações',
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),
                                  if (transactionsState.transactions.isEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16.0),
                                      child: Center(
                                        child: Text(
                                          'Nenhuma transação Pix realizada',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                  else
                                    PixTransactionList(
                                      transactions:
                                          transactionsState.transactions,
                                    ),
                                ],
                              ),
                            ),
                          )
                        else if (transactionsState is PixTransactionsErrorState)
                          Card(
                            elevation: 2.0,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'Erro ao carregar transações: ${transactionsState.message}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _getPixKeyTypeIcon(PixKeyType type) {
    late IconData iconData;
    late Color iconColor;

    switch (type) {
      case PixKeyType.cpf:
        iconData = Icons.badge;
        iconColor = Colors.blue;
        break;
      case PixKeyType.cnpj:
        iconData = Icons.business;
        iconColor = Colors.purple;
        break;
      case PixKeyType.email:
        iconData = Icons.email;
        iconColor = Colors.red;
        break;
      case PixKeyType.phone:
        iconData = Icons.phone;
        iconColor = Colors.green;
        break;
      case PixKeyType.random:
        iconData = Icons.vpn_key;
        iconColor = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(25),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
      ),
    );
  }
}
