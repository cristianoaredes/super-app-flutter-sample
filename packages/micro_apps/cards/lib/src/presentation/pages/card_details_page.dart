import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/card_details_bloc.dart';
import '../bloc/card_details_event.dart';
import '../bloc/card_details_state.dart';
import '../widgets/card_details_content.dart';

class CardDetailsPage extends StatefulWidget {
  final String cardId;

  const CardDetailsPage({
    Key? key,
    required this.cardId,
  }) : super(key: key);

  @override
  State<CardDetailsPage> createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends State<CardDetailsPage> {
  late final CardDetailsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.I.get<CardDetailsBloc>();
    _bloc.add(LoadCardDetailsEvent(cardId: widget.cardId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Cartão'),
      ),
      body: BlocConsumer<CardDetailsBloc, CardDetailsState>(
        bloc: _bloc,
        listenWhen: (previous, current) =>
            current is CardDetailsErrorState ||
            current is CardBlockedState ||
            current is CardUnblockedState,
        listener: (context, state) {
          if (state is CardDetailsErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is CardBlockedState) {
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
          }
        },
        buildWhen: (previous, current) =>
            current is CardDetailsLoadingState ||
            current is CardDetailsLoadedState ||
            current is CardDetailsErrorState ||
            current is CardBlockedState ||
            current is CardUnblockedState,
        builder: (context, state) {
          if (state is CardDetailsLoadingState) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is CardDetailsLoadedState ||
              state is CardBlockedState ||
              state is CardUnblockedState) {
            final card = state is CardDetailsLoadedState
                ? state.card
                : state is CardBlockedState
                    ? state.card
                    : (state as CardUnblockedState).card;

            return CardDetailsContent(
              card: card,
              onBlockCard: () {
                _bloc.add(BlockCardEvent(cardId: card.id));
              },
              onUnblockCard: () {
                _bloc.add(UnblockCardEvent(cardId: card.id));
              },
              onLoadStatement: (startDate, endDate) {
                _bloc.add(LoadCardStatementEvent(
                  cardId: card.id,
                  startDate: startDate,
                  endDate: endDate,
                ));
              },
            );
          }

          if (state is CardDetailsErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _bloc.add(LoadCardDetailsEvent(cardId: widget.cardId));
                    },
                    child: const Text('Tentar Novamente'),
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
}
