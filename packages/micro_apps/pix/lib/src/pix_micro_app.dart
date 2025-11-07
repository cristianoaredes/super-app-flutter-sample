import 'package:core_interfaces/core_interfaces.dart' hide BlocProvider;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_utils/shared_utils.dart';

import 'di/pix_injector.dart';
import 'presentation/bloc/pix_bloc.dart';
import 'presentation/pages/pix_home_page.dart';
import 'presentation/pages/pix_keys_page.dart';
import 'presentation/pages/register_pix_key_page.dart';
import 'presentation/pages/send_pix_page.dart';
import 'presentation/pages/receive_pix_page.dart';
import 'presentation/pages/pix_qr_code_scanner_page.dart';
import 'presentation/pages/pix_transaction_details_page.dart';
import 'presentation/widgets/error_page.dart';

/// Micro app de Pix
///
/// Gerencia funcionalidades de:
/// - Transferências via Pix
/// - Gerenciamento de chaves Pix
/// - Recebimento via QR Code
/// - Histórico de transações Pix
class PixMicroApp extends BaseMicroApp {
  PixBloc? _pixBloc;

  PixMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'pix';

  @override
  String get name => 'Pix';

  /// Retorna a instância do PixBloc
  ///
  /// Throws [InvalidStateException] se o micro app não foi inicializado.
  PixBloc get pixBloc {
    ensureInitialized();

    if (_pixBloc == null) {
      throw InvalidStateException(
        message: 'PixBloc não foi inicializado corretamente.',
      );
    }

    return _pixBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/pix': (context, state) {
          ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => pixBloc,
            child: const PixHomePage(),
          );
        },
        '/pix/keys': (context, state) {
          ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => pixBloc,
            child: const PixKeysPage(),
          );
        },
        '/pix/keys/register': (context, state) {
          ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => pixBloc,
            child: const RegisterPixKeyPage(),
          );
        },
        '/pix/send': (context, state) {
          ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => pixBloc,
            child: const SendPixPage(),
          );
        },
        '/pix/receive': (context, state) {
          ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => pixBloc,
            child: const ReceivePixPage(),
          );
        },
        '/pix/scan': (context, state) {
          ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => pixBloc,
            child: const PixQrCodeScannerPage(),
          );
        },
        '/pix/transaction/:id': (context, state) {
          ensureInitialized();

          try {
            // Valida parâmetro de rota
            final id = RouteParamsValidator.getRequiredParam(
              state.params,
              'id',
            );

            return BlocProvider<PixBloc>(
              create: (context) => pixBloc,
              child: PixTransactionDetailsPage(transactionId: id),
            );
          } on RouteParamException catch (e) {
            return ErrorPage(message: e.message);
          }
        },
      };

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Registrar dependências e criação do bloc
    PixInjector.register(getIt);

    // Inicializa o PixBloc após o registro das dependências
    _pixBloc = getIt<PixBloc>();
  }

  @override
  Future<void> onDispose() async {
    if (_pixBloc != null) {
      try {
        await _pixBloc!.close();
      } catch (e) {
        dependencies.loggingService?.warning(
          'Erro ao fechar PixBloc: $e',
          tag: 'PixMicroApp',
        );
      } finally {
        _pixBloc = null;
      }
    }

    // Limpa o registro do GetIt para garantir que novas instâncias sejam criadas
    try {
      if (getIt.isRegistered<PixBloc>()) {
        getIt.unregister<PixBloc>();
      }
    } catch (e) {
      dependencies.loggingService?.warning(
        'Erro ao limpar registro do PixBloc: $e',
        tag: 'PixMicroApp',
      );
    }
  }

  @override
  Future<bool> checkHealth() async {
    if (_pixBloc == null) {
      return false;
    }

    try {
      // Verifica se o Bloc está em estado válido
      final state = _pixBloc!.state;
      return state != null;
    } catch (e) {
      dependencies.loggingService?.error(
        'Health check falhou para PixBloc',
        error: e,
        tag: 'PixMicroApp',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return BlocProvider<PixBloc>(
      create: (context) => pixBloc,
      child: const PixHomePage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register<PixBloc>(pixBloc);
  }
}
