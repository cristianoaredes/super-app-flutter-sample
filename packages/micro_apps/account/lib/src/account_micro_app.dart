import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:flutter/material.dart';

import 'di/account_injector.dart';
import 'presentation/bloc/account_bloc.dart';
import 'presentation/pages/account_page.dart';
import 'presentation/pages/account_details_page.dart';
import 'presentation/pages/account_statement_page.dart';
import 'presentation/pages/transfer_page.dart';

/// Micro app de Conta
///
/// Gerencia funcionalidades de:
/// - Visualização de saldo e informações da conta
/// - Detalhes da conta (agência, conta, CPF)
/// - Extrato da conta
/// - Transferências bancárias
class AccountMicroApp extends BaseMicroApp {
  AccountBloc? _accountBloc;

  AccountMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'account';

  @override
  String get name => 'Conta';

  /// Retorna a instância do AccountBloc
  ///
  /// Throws [InvalidStateException] se o micro app não foi inicializado.
  AccountBloc get accountBloc {
    ensureInitialized();

    if (_accountBloc == null) {
      throw InvalidStateException(
        message: 'AccountBloc não foi inicializado corretamente.',
      );
    }

    return _accountBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/account': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<AccountBloc>.value(
            value: accountBloc,
            child: const AccountPage(),
          );
        },
        '/account/details': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<AccountBloc>.value(
            value: accountBloc,
            child: const AccountDetailsPage(),
          );
        },
        '/account/statement': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<AccountBloc>.value(
            value: accountBloc,
            child: const AccountStatementPage(),
          );
        },
        '/account/transfer': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<AccountBloc>.value(
            value: accountBloc,
            child: const TransferPage(),
          );
        },
      };

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Registrar dependências
    AccountInjector.register(getIt);

    // Inicializa o AccountBloc
    _accountBloc = getIt<AccountBloc>();
  }

  @override
  Future<void> onDispose() async {
    if (_accountBloc != null) {
      try {
        await _accountBloc!.close();
      } catch (e) {
        dependencies.loggingService?.warning(
          'Erro ao fechar AccountBloc: $e',
          tag: 'AccountMicroApp',
        );
      } finally {
        _accountBloc = null;
      }
    }
  }

  @override
  Future<bool> checkHealth() async {
    if (_accountBloc == null) {
      return false;
    }

    try {
      // Verifica se o Bloc está em estado válido
      final state = _accountBloc!.state;
      return state != null;
    } catch (e) {
      dependencies.loggingService?.error(
        'Health check falhou para AccountBloc',
        error: e,
        tag: 'AccountMicroApp',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return flutter_bloc.BlocProvider.value(
      value: accountBloc,
      child: const AccountPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register<AccountBloc>(accountBloc);
  }
}
