import 'package:flutter/material.dart' hide Card;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/card.dart';
import '../bloc/cards_bloc.dart';
import '../bloc/cards_event.dart';
import '../bloc/cards_state.dart';
import '../widgets/card_details_header.dart';


class CardDetailsPage extends StatefulWidget {
  final String cardId;

  const CardDetailsPage({
    super.key,
    required this.cardId,
  });

  @override
  State<CardDetailsPage> createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends State<CardDetailsPage> {
  @override
  void initState() {
    super.initState();
    context.read<CardsBloc>().add(LoadCardEvent(cardId: widget.cardId));
  }

  void _navigateToCardStatement() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo(
      '/cards/:id/statement',
      params: {'id': widget.cardId},
    );
  }

  void _blockCard(Card card) {
    if (card.isBlocked) {
      context.read<CardsBloc>().add(UnblockCardEvent(cardId: card.id));
    } else {
      context.read<CardsBloc>().add(BlockCardEvent(cardId: card.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Cartão'),
      ),
      body: BlocConsumer<CardsBloc, CardsState>(
        listener: (context, state) {
          if (state is CardBlockedState) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cartão bloqueado com sucesso'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is CardUnblockedState) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cartão desbloqueado com sucesso'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is CardErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CardLoadingState) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is CardLoadedState ||
              state is CardBlockedState ||
              state is CardUnblockedState) {
            final card = state is CardLoadedState
                ? state.card
                : state is CardBlockedState
                    ? state.card
                    : (state as CardUnblockedState).card;

            return _buildCardDetails(context, card);
          }

          if (state is CardErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar o cartão',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<CardsBloc>().add(
                            LoadCardEvent(cardId: widget.cardId),
                          );
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildCardDetails(BuildContext context, Card card) {
    final isBlocking = context.watch<CardsBloc>().state is CardBlockingState;
    final isUnblocking =
        context.watch<CardsBloc>().state is CardUnblockingState;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        CardDetailsHeader(card: card),
        const SizedBox(height: 24.0),
        Material(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informações do Cartão',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                _buildInfoRow('Número', card.maskedNumber),
                const Divider(),
                _buildInfoRow('Titular', card.holderName),
                const Divider(),
                _buildInfoRow('Validade', card.expirationDate.toBR),
                const Divider(),
                _buildInfoRow('Tipo', card.type),
                const Divider(),
                _buildInfoRow('Bandeira', card.brand),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Material(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Limites',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                _buildFinancialRow(
                  'Limite Total',
                  card.limit.toBRL,
                  Colors.blue,
                ),
                const Divider(),
                _buildFinancialRow(
                  'Limite Disponível',
                  card.availableLimit.toBRL,
                  Colors.green,
                ),
                const Divider(),
                _buildFinancialRow(
                  'Limite Utilizado',
                  (card.limit - card.availableLimit).toBRL,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Material(
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
                      _navigateToCardStatement,
                    ),
                    _buildActionButton(
                      context,
                      card.isBlocked ? 'Desbloquear' : 'Bloquear',
                      card.isBlocked ? Icons.lock_open : Icons.lock,
                      () => _blockCard(card),
                      isLoading: isBlocking || isUnblocking,
                      color: card.isBlocked ? Colors.green : Colors.red,
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
    VoidCallback onPressed, {
    bool isLoading = false,
    Color? color,
  }) {
    return Column(
      children: [
        Material(
          color: color != null
              ? color.withOpacity(0.1)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.0),
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: isLoading
                  ? CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        color ?? Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 32.0,
                      color: color ?? Theme.of(context).colorScheme.primary,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
