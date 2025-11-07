import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:flutter/material.dart';
import 'package:shared_utils/shared_utils.dart';

import 'di/cards_injector.dart';
import 'presentation/bloc/cards_bloc.dart';
import 'presentation/pages/cards_page.dart';
import 'presentation/pages/card_details_page.dart';
import 'presentation/pages/card_statement_page.dart';
import 'presentation/widgets/error_page.dart';

/// Micro app de Cartões
///
/// Gerencia funcionalidades de:
/// - Listagem de cartões (débito e crédito)
/// - Detalhes do cartão (limite, fatura, etc)
/// - Extrato do cartão
/// - Gerenciamento de cartões virtuais
class CardsMicroApp extends BaseMicroApp {
  CardsBloc? _cardsBloc;

  CardsMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'cards';

  @override
  String get name => 'Cartões';

  /// Retorna a instância do CardsBloc
  ///
  /// Throws [InvalidStateException] se o micro app não foi inicializado.
  CardsBloc get cardsBloc {
    ensureInitialized();

    if (_cardsBloc == null) {
      throw InvalidStateException(
        message: 'CardsBloc não foi inicializado corretamente.',
      );
    }

    return _cardsBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/cards': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<CardsBloc>.value(
            value: cardsBloc,
            child: const CardsPage(),
          );
        },
        '/cards/:id': (context, state) {
          ensureInitialized();

          try {
            // Valida parâmetro de rota
            final id = RouteParamsValidator.getRequiredParam(
              state.params,
              'id',
            );

            return flutter_bloc.BlocProvider<CardsBloc>.value(
              value: cardsBloc,
              child: CardDetailsPage(cardId: id),
            );
          } on RouteParamException catch (e) {
            return ErrorPage(message: e.message);
          }
        },
        '/cards/:id/statement': (context, state) {
          ensureInitialized();

          try {
            // Valida parâmetro de rota
            final id = RouteParamsValidator.getRequiredParam(
              state.params,
              'id',
            );

            return flutter_bloc.BlocProvider<CardsBloc>.value(
              value: cardsBloc,
              child: CardStatementPage(cardId: id),
            );
          } on RouteParamException catch (e) {
            return ErrorPage(message: e.message);
          }
        },
      };

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Registrar dependências
    CardsInjector.register(getIt);

    // Inicializa o CardsBloc
    _cardsBloc = getIt<CardsBloc>();
  }

  @override
  Future<void> onDispose() async {
    if (_cardsBloc != null) {
      try {
        await _cardsBloc!.close();
      } catch (e) {
        dependencies.loggingService?.warning(
          'Erro ao fechar CardsBloc: $e',
          tag: 'CardsMicroApp',
        );
      } finally {
        _cardsBloc = null;
      }
    }
  }

  @override
  Future<bool> checkHealth() async {
    if (_cardsBloc == null) {
      return false;
    }

    try {
      // Verifica se o Bloc está em estado válido
      final state = _cardsBloc!.state;
      return state != null;
    } catch (e) {
      dependencies.loggingService?.error(
        'Health check falhou para CardsBloc',
        error: e,
        tag: 'CardsMicroApp',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return flutter_bloc.BlocProvider.value(
      value: cardsBloc,
      child: const CardsPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register<CardsBloc>(cardsBloc);
  }
}
