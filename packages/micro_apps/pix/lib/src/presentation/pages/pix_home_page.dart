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
                  if (state is PixKeysLoadingState) {
                    return const Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (state is PixKeysLoadedState) {
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
                            if (state.keys.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    'Você ainda não possui chaves Pix cadastradas',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.keys.length > 3
                                    ? 3
                                    : state.keys.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(),
                                itemBuilder: (context, index) {
                                  final key = state.keys[index];
                                  return ListTile(
                                    title: Text(key.formattedName),
                                    subtitle: Text(key.formattedValue),
                                    leading: _getPixKeyTypeIcon(key.type),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state is PixKeysErrorState) {
                    return Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Minhas Chaves',
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
                                    'Erro ao carregar as chaves: ${state.message}',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8.0),
                                  ElevatedButton(
                                    onPressed: () {
                                      _loadDataSafely();
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
              const SizedBox(height: 24.0),
              BlocBuilder<PixBloc, PixState>(
                builder: (context, state) {
                  if (state is PixTransactionsLoadingState) {
                    return const Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (state is PixTransactionsLoadedState) {
                    return Card(
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
                            PixTransactionList(
                              transactions: state.transactions,
                              maxItems: 5,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state is PixTransactionsErrorState) {
                    return Card(
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
                                      _loadDataSafely();
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
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
      ),
    );
  }
}
