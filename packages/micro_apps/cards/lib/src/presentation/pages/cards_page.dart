import 'package:flutter/material.dart' hide Card;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/card.dart';

import '../bloc/cards_bloc.dart';
import '../bloc/cards_event.dart';
import '../bloc/cards_state.dart';
import '../widgets/card_item.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  late final CardsBloc _cardsBloc;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cardsBloc = GetIt.instance<CardsBloc>();
    _ensureDataLoaded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    GetIt.instance<RouteObserver<ModalRoute<void>>>()
        .subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    GetIt.instance<RouteObserver<ModalRoute<void>>>().unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (mounted) {
      _refreshCards();
    }
  }

  void _ensureDataLoaded() {
    if (!_cardsBloc.isInitialized) {
      _cardsBloc.add(const LoadCardsEvent());
    }
  }

  void _refreshCards() {
    if (!mounted) return;
    _cardsBloc.add(const RefreshCardsEvent());
  }

  void _navigateToCardDetails(String cardId) {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/cards/:id', params: {'id': cardId});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meus Cartões'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshCards,
            ),
          ],
        ),
        body: BlocConsumer<CardsBloc, CardsState>(
          bloc: _cardsBloc,
          listenWhen: (previous, current) {
            return current is CardsErrorState &&
                (previous is! CardsErrorState ||
                    previous.message != current.message);
          },
          listener: (context, state) {
            if (state is CardsErrorState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          buildWhen: (previous, current) {
            if (current is CardsLoadingWithDataState &&
                previous is CardsLoadedState) {
              return false;
            }
            return true;
          },
          builder: (context, state) {
            if (state is CardsInitialState) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is CardsLoadingState) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is CardsLoadingWithDataState) {
              return _buildCardsList(context, state.cards, isLoading: true);
            }

            if (state is CardsLoadedState) {
              return _buildCardsList(context, state.cards);
            }

            if (state is CardsErrorState) {
              if (state.cards != null && state.cards!.isNotEmpty) {
                return _buildCardsList(context, state.cards,
                    errorMessage: state.message);
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erro ao carregar os cartões',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(state.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshCards,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildCardsList(
    BuildContext context,
    List<Card>? cards, {
    bool isLoading = false,
    String? errorMessage,
  }) {
    if (cards == null || cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.credit_card,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum cartão encontrado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione um novo cartão para começar',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Adicionar Cartão'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            _refreshCards();

            await Future.delayed(const Duration(seconds: 1));
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        onPressed: _refreshCards,
                      ),
                    ],
                  ),
                ),
              ...cards.map((card) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: CardItem(
                      card: card,
                      onTap: () => _navigateToCardDetails(card.id),
                    ),
                  )),
            ],
          ),
        ),
        if (isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }
}
