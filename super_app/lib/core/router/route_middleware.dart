import 'dart:async';

import 'package:core_interfaces/core_interfaces.dart' hide GoRouterState;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Um middleware de rota que inicializa micro apps sob demanda antes de navegação
class MicroAppInitializerMiddleware {
  final GetIt _getIt;
  final LoggingService _loggingService;

  // Controle de micro apps em reinicialização
  final Set<String> _microAppsBeingReinitialized = {};

  MicroAppInitializerMiddleware({
    required GetIt getIt,
  })  : _getIt = getIt,
        _loggingService = getIt<LoggingService>();

  /// Mapeamento de prefixos de rotas para nomes de micro apps
  final Map<String, String> _routePrefixToMicroApp = {
    '/payments': 'payments',
    '/pix': 'pix',
    '/cards': 'cards',
    '/account': 'account',
    '/dashboard': 'dashboard',
  };

  /// Verifica se a rota requer inicialização de um micro app específico
  String? _getMicroAppNameForRoute(String path) {
    for (final entry in _routePrefixToMicroApp.entries) {
      if (path.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Função redirect do GoRouter que inicializará o micro app necessário
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) async {
    final path = state.matchedLocation;
    final microAppName = _getMicroAppNameForRoute(path);

    if (microAppName != null) {
      // Se este micro app está sendo reinicializado, redirecione para o dashboard
      if (_microAppsBeingReinitialized.contains(microAppName)) {
        _loggingService.info(
            'Micro app $microAppName está em processo de reinicialização, redirecionando para o dashboard');
        return '/dashboard';
      }

      try {
        final microApp = _getIt<MicroApp>(instanceName: microAppName);
        bool needsReinitialization = false;

        // Se o micro app já estiver inicializado, verificamos se está em um estado válido
        if (microApp.isInitialized) {
          try {
            // Verificação de saúde - tentamos acessar o build apenas para
            // ver se ocorre alguma exceção
            microApp.build(context);
            return null; // Continue para a rota original se tudo estiver ok
          } catch (e) {
            // O micro app parece estar em um estado inválido
            _loggingService.warning(
                'Micro app $microAppName está em estado inválido e será reinicializado: $e');
            needsReinitialization = true;
          }
        }

        // Se precisamos reinicializar ou inicializar pela primeira vez
        if (!microApp.isInitialized || needsReinitialization) {
          _microAppsBeingReinitialized.add(microAppName);

          try {
            // Se estamos reinicializando, primeiro descartamos o micro app atual
            if (needsReinitialization) {
              await microApp.dispose();

              // Resetamos registros específicos se necessário
              await _resetMicroAppRegistrations(microAppName);
            }

            _loggingService
                .info('Inicializando micro app sob demanda: $microAppName');

            // Recupera a função de inicialização registrada
            final initializeMicroApp = _getIt<Future<void> Function(String)>(
                instanceName: 'initializeMicroApp');

            // Inicializa o micro app
            await initializeMicroApp(microAppName);

            _loggingService
                .info('Micro app $microAppName inicializado com sucesso');

            // Remove da lista de reinicialização
            _microAppsBeingReinitialized.remove(microAppName);
          } catch (e) {
            _microAppsBeingReinitialized.remove(microAppName);
            _loggingService
                .error('Erro ao inicializar micro app $microAppName: $e');
            return '/error'; // Redirecione para uma página de erro
          }
        }

        return null; // Continue para a rota original
      } catch (e) {
        _loggingService
            .error('Erro ao inicializar micro app $microAppName: $e');
        if (kDebugMode) {
          print('Erro ao inicializar micro app $microAppName: $e');
        }
        return '/error'; // Redirecione para uma página de erro
      }
    }

    return null; // Continue para a rota original se não precisar inicializar nenhum micro app
  }

  // Método para limpar registros específicos do GetIt para diferentes micro apps
  Future<void> _resetMicroAppRegistrations(String microAppName) async {
    try {
      // Limpeza específica para cada micro app se necessário
      switch (microAppName) {
        case 'pix':
          // Aqui poderíamos limpar registros específicos se necessário
          break;
        case 'payments':
          // Aqui poderíamos limpar registros específicos se necessário
          break;
        default:
          break;
      }
    } catch (e) {
      _loggingService.warning('Erro ao limpar registros do $microAppName: $e');
    }
  }
}
