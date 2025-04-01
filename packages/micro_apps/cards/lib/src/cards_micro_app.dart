import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'di/cards_injector.dart';
import 'presentation/bloc/cards_bloc.dart';
import 'presentation/pages/cards_page.dart';
import 'presentation/pages/card_details_page.dart';
import 'presentation/pages/card_statement_page.dart';


class CardsMicroApp implements MicroApp {
  final GetIt _getIt;
  CardsBloc? _cardsBloc;
  bool _initialized = false;

  CardsMicroApp({GetIt? getIt}) : _getIt = getIt ?? GetIt.instance;

  @override
  String get id => 'cards';

  @override
  String get name => 'Cartões';

  @override
  bool get isInitialized => _initialized;

  
  CardsBloc get cardsBloc {
    if (!_initialized) {
      throw StateError(
          'CardsMicroApp não foi inicializado. Chame initialize() primeiro.');
    }
    return _cardsBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/cards': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<CardsBloc>.value(
            value: cardsBloc,
            child: const CardsPage(),
          );
        },
        '/cards/:id': (context, state) {
          _ensureInitialized();
          final id = state.params['id'] ?? '';
          return flutter_bloc.BlocProvider<CardsBloc>.value(
            value: cardsBloc,
            child: CardDetailsPage(cardId: id),
          );
        },
        '/cards/:id/statement': (context, state) {
          _ensureInitialized();
          final id = state.params['id'] ?? '';
          return flutter_bloc.BlocProvider<CardsBloc>.value(
            value: cardsBloc,
            child: CardStatementPage(cardId: id),
          );
        },
      };

  
  void _ensureInitialized() {
    if (!_initialized) {
      
      CardsInjector.register(_getIt);
      _cardsBloc = _getIt<CardsBloc>();
      _initialized = true;
    }
  }

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) return;

    
    CardsInjector.register(_getIt);
    _cardsBloc = _getIt<CardsBloc>();

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialized();
    return flutter_bloc.BlocProvider.value(
      value: cardsBloc,
      child: const CardsPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    _ensureInitialized();
    registry.register(cardsBloc);
  }

  @override
  Future<void> dispose() async {
    if (_initialized && _cardsBloc != null) {
      await _cardsBloc!.close();
    }
  }
}
