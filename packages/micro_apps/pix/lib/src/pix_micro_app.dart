import 'package:core_interfaces/core_interfaces.dart' hide BlocProvider;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'di/pix_injector.dart';
import 'presentation/bloc/pix_bloc.dart';
import 'presentation/pages/pix_home_page.dart';
import 'presentation/pages/pix_keys_page.dart';
import 'presentation/pages/register_pix_key_page.dart';
import 'presentation/pages/send_pix_page.dart';
import 'presentation/pages/receive_pix_page.dart';
import 'presentation/pages/pix_qr_code_scanner_page.dart';
import 'presentation/pages/pix_transaction_details_page.dart';

class PixMicroApp implements MicroApp {
  final GetIt _getIt;
  bool _initialized = false;
  PixBloc? _pixBloc;
  MicroAppDependencies? _dependencies;

  PixMicroApp({GetIt? getIt}) : _getIt = getIt ?? GetIt.instance;

  @override
  String get id => 'pix';

  @override
  String get name => 'Pix';

  @override
  bool get isInitialized => _initialized;

  PixBloc get pixBloc {
    _ensureInitialized();

    // Sempre cria uma nova instância do PixBloc para evitar problemas de ciclo de vida
    try {
      // Fecha o bloc anterior se existir
      if (_pixBloc != null) {
        try {
          _pixBloc!.close();
        } catch (e) {
          // Ignora erros ao fechar
          debugPrint('Erro ao fechar PixBloc anterior: $e');
        }
      }

      // Cria uma nova instância
      _pixBloc = _getIt<PixBloc>();
    } catch (e) {
      debugPrint('Erro ao obter PixBloc do GetIt: $e');
      // Se não conseguiu obter do GetIt, tente reinicializar
      if (_dependencies != null) {
        PixInjector.register(_getIt);
        try {
          _pixBloc = _getIt<PixBloc>();
        } catch (e) {
          debugPrint('Erro ao recriar PixBloc: $e');
          throw StateError('Não foi possível recuperar ou recriar o PixBloc');
        }
      } else {
        throw StateError(
            'Não é possível recriar o PixBloc sem as dependências');
      }
    }

    return _pixBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/pix': (context, state) {
          _ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => _getIt<PixBloc>(),
            child: const PixHomePage(),
          );
        },
        '/pix/keys': (context, state) {
          _ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => _getIt<PixBloc>(),
            child: const PixKeysPage(),
          );
        },
        '/pix/keys/register': (context, state) {
          _ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => _getIt<PixBloc>(),
            child: const RegisterPixKeyPage(),
          );
        },
        '/pix/send': (context, state) {
          _ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => _getIt<PixBloc>(),
            child: const SendPixPage(),
          );
        },
        '/pix/receive': (context, state) {
          _ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => _getIt<PixBloc>(),
            child: const ReceivePixPage(),
          );
        },
        '/pix/scan': (context, state) {
          _ensureInitialized();
          return BlocProvider<PixBloc>(
            create: (context) => _getIt<PixBloc>(),
            child: const PixQrCodeScannerPage(),
          );
        },
        '/pix/transaction/:id': (context, state) {
          _ensureInitialized();
          final id = state.params['id'] ?? '';
          return BlocProvider<PixBloc>(
            create: (context) => _getIt<PixBloc>(),
            child: PixTransactionDetailsPage(transactionId: id),
          );
        },
      };

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
          'PixMicroApp não foi inicializado. Chame initialize() primeiro.');
    }

    if (_pixBloc == null) {
      throw StateError(
          'PixBloc não foi inicializado corretamente. Problema na inicialização do micro app.');
    }
  }

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) return;

    _dependencies = dependencies;

    // Registrar dependências e criação do bloc
    PixInjector.register(_getIt);

    // Inicializa o PixBloc após o registro das dependências
    _pixBloc = _getIt<PixBloc>();

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialized();
    return BlocProvider<PixBloc>(
      create: (context) => pixBloc,
      child: const PixHomePage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    _ensureInitialized();
    registry.register(pixBloc);
  }

  @override
  Future<void> dispose() async {
    if (_pixBloc != null) {
      try {
        await _pixBloc!.close();
      } catch (e) {
        // Ignora exceções durante o fechamento
        debugPrint('Erro ao fechar PixBloc: $e');
      } finally {
        _pixBloc = null;
      }
    }

    // Limpa o registro do GetIt para garantir que novas instâncias sejam criadas
    try {
      if (_getIt.isRegistered<PixBloc>()) {
        _getIt.unregister<PixBloc>();
      }
    } catch (e) {
      debugPrint('Erro ao limpar registro do PixBloc: $e');
    }

    // Definimos explicitamente como não inicializado após o dispose
    // para garantir que uma nova instância seja criada se necessário
    _initialized = false;
  }
}
