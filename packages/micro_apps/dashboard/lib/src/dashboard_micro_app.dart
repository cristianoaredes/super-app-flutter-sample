import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:get_it/get_it.dart';
import 'package:shared_utils/shared_utils.dart';

import 'di/dashboard_injector.dart';
import 'presentation/bloc/dashboard_bloc.dart';
import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/account_details_page.dart';
import 'presentation/pages/transaction_details_page.dart';
import 'presentation/widgets/error_page.dart';

/// Micro app do Dashboard
///
/// Gerencia funcionalidades de:
/// - Visão geral da conta (saldo, últimas transações)
/// - Detalhes da conta
/// - Detalhes de transações
/// - Gráficos e estatísticas
class DashboardMicroApp extends BaseMicroApp {
  DashboardBloc? _dashboardBloc;

  DashboardMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'dashboard';

  @override
  String get name => 'Dashboard';

  /// Retorna a instância do DashboardBloc
  ///
  /// Throws [InvalidStateException] se o micro app não foi inicializado.
  DashboardBloc get dashboardBloc {
    ensureInitialized();
    return _dashboardBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/dashboard': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<DashboardBloc>.value(
            value: dashboardBloc,
            child: const DashboardPage(),
          );
        },
        '/dashboard/account': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<DashboardBloc>.value(
            value: dashboardBloc,
            child: const AccountDetailsPage(),
          );
        },
        '/dashboard/transaction/:id': (context, state) {
          ensureInitialized();

          try {
            // Valida parâmetro de rota
            final id = RouteParamsValidator.getRequiredParam(
              state.params,
              'id',
            );

            return flutter_bloc.BlocProvider<DashboardBloc>.value(
              value: dashboardBloc,
              child: TransactionDetailsPage(transactionId: id),
            );
          } on RouteParamException catch (e) {
            return ErrorPage(message: e.message);
          }
        },
      };

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Registrar dependências do módulo dashboard
    DashboardInjector.register(getIt);

    // Criar instância do DashboardBloc
    _dashboardBloc = getIt<DashboardBloc>();
  }

  @override
  Future<void> onDispose() async {
    if (_dashboardBloc != null) {
      await _dashboardBloc!.close();
      _dashboardBloc = null;
    }
  }

  @override
  Future<bool> checkHealth() async {
    if (_dashboardBloc == null) {
      return false;
    }

    try {
      // Verifica se o BLoC está em estado válido
      final state = _dashboardBloc!.state;
      return state != null;
    } catch (e) {
      dependencies.loggingService?.error(
        'Health check falhou para DashboardBloc',
        error: e,
        tag: 'DashboardMicroApp',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return flutter_bloc.BlocProvider.value(
      value: dashboardBloc,
      child: const DashboardPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register(dashboardBloc);
  }
}
