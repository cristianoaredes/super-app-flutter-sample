import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'data/repositories/payment_repository_impl.dart';
import 'data/datasources/payment_remote_data_source.dart';
import 'data/datasources/payment_mock_datasource.dart';
import 'presentation/cubits/payments_cubit.dart';
import 'presentation/pages/payment_detail_page.dart';
import 'presentation/pages/payments_page.dart';

class PaymentsMicroApp implements MicroApp {
  PaymentsCubit? _paymentsCubit;
  bool _initialized = false;

  // Armazene as dependências para usar posteriormente quando criar novos Cubits
  MicroAppDependencies? _dependencies;
  PaymentRepositoryImpl? _paymentRepository;

  @override
  String get id => 'payments';

  @override
  String get name => 'Payments';

  @override
  bool get isInitialized => _initialized;

  PaymentsCubit get paymentsCubit {
    if (!_initialized) {
      throw StateError(
          'PaymentsMicroApp não foi inicializado. Chame initialize() primeiro.');
    }

    // Se o cubit foi fechado ou é nulo, crie um novo
    if (_paymentsCubit == null) {
      if (_paymentRepository != null) {
        _createCubit();
      } else {
        throw StateError(
            'PaymentsCubit não pode ser criado porque o repositório não está disponível.');
      }
    }

    return _paymentsCubit!;
  }

  // Cria um novo PaymentsCubit usando o repositório configurado
  void _createCubit() {
    if (_paymentRepository != null && _dependencies != null) {
      _paymentsCubit = PaymentsCubit(
        repository: _paymentRepository!,
        analyticsService: _dependencies!.analyticsService,
      );
    }
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/payments': (context, state) {
          _ensureInitialized();

          return flutter_bloc.BlocProvider<PaymentsCubit>(
            create: (context) => paymentsCubit,
            child: const PaymentsPage(),
          );
        },
        '/payments/:id': (context, state) {
          _ensureInitialized();
          final id = state.params['id']!;

          return flutter_bloc.BlocProvider<PaymentsCubit>(
            create: (context) => paymentsCubit,
            child: PaymentDetailPage(id: id),
          );
        },
      };

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
          'PaymentsMicroApp has not been initialized. Call initialize() first.');
    }

    if (_paymentsCubit == null) {
      _createCubit();
      if (_paymentsCubit == null) {
        throw StateError(
            'PaymentsCubit não foi inicializado corretamente. Problema na inicialização do micro app.');
      }
    }
  }

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) return;

    // Armazenamos as dependências para uso posterior
    _dependencies = dependencies;

    if (!kIsWeb) {
      try {
        final tempDir = Directory.systemTemp.createTempSync('hydrated_bloc');
        HydratedBloc.storage = await HydratedStorage.build(
          storageDirectory: tempDir,
        );
      } catch (e) {}
    }

    final useMockData =
        dependencies.config.getValue<bool>('mock_data') ?? false;

    PaymentRemoteDataSource remoteDataSource;

    if (useMockData) {
      if (kDebugMode) {
        print('🌐 Using PaymentMockDataSource for development environment');
      }
      remoteDataSource = PaymentMockDataSource();
    } else {
      remoteDataSource = PaymentRemoteDataSourceImpl(
        dependencies.networkService.createClient(
          baseUrl: dependencies.config.apiBaseUrl,
        ),
      );
    }

    _paymentRepository = PaymentRepositoryImpl(
      remoteDataSource: remoteDataSource,
      authService: dependencies.authService,
    );

    // Cria o cubit inicial
    _createCubit();

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialized();
    return flutter_bloc.BlocProvider<PaymentsCubit>(
      create: (context) => paymentsCubit,
      child: const PaymentsPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    _ensureInitialized();
    registry.register<PaymentsCubit>(paymentsCubit);
  }

  @override
  Future<void> dispose() async {
    if (_initialized && _paymentsCubit != null) {
      try {
        await _paymentsCubit!.close();
      } catch (e) {
        // Ignora exceções durante o fechamento
        debugPrint('Erro ao fechar PaymentsCubit: $e');
      } finally {
        _paymentsCubit = null;
        _initialized = false;
      }
    }

    // Mas mantenha o repositório configurado para uso futuro
    // _paymentRepository = null;
    // _dependencies = null;
  }
}
