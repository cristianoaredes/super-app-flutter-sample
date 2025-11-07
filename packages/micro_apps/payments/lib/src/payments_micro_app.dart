import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shared_utils/shared_utils.dart';

import 'data/repositories/payment_repository_impl.dart';
import 'data/datasources/payment_remote_data_source.dart';
import 'data/datasources/payment_mock_datasource.dart';
import 'presentation/cubits/payments_cubit.dart';
import 'presentation/pages/payment_detail_page.dart';
import 'presentation/pages/payments_page.dart';
import 'presentation/widgets/error_page.dart';

/// Micro app de Pagamentos
///
/// Gerencia funcionalidades de:
/// - Listagem de pagamentos
/// - Detalhes de pagamento
/// - Criação de novos pagamentos
/// - Histórico de pagamentos
class PaymentsMicroApp extends BaseMicroApp {
  PaymentsCubit? _paymentsCubit;
  PaymentRepositoryImpl? _paymentRepository;

  PaymentsMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'payments';

  @override
  String get name => 'Payments';

  /// Retorna a instância do PaymentsCubit
  ///
  /// Throws [InvalidStateException] se o micro app não foi inicializado.
  PaymentsCubit get paymentsCubit {
    ensureInitialized();

    if (_paymentsCubit == null) {
      throw InvalidStateException(
        message: 'PaymentsCubit não foi inicializado corretamente.',
      );
    }

    return _paymentsCubit!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/payments': (context, state) {
          ensureInitialized();

          return flutter_bloc.BlocProvider<PaymentsCubit>(
            create: (context) => paymentsCubit,
            child: const PaymentsPage(),
          );
        },
        '/payments/:id': (context, state) {
          ensureInitialized();

          try {
            // Valida parâmetro de rota
            final id = RouteParamsValidator.getRequiredParam(
              state.params,
              'id',
            );

            return flutter_bloc.BlocProvider<PaymentsCubit>(
              create: (context) => paymentsCubit,
              child: PaymentDetailPage(id: id),
            );
          } on RouteParamException catch (e) {
            return ErrorPage(message: e.message);
          }
        },
      };

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Configurar HydratedBloc para persistência (apenas mobile/desktop)
    if (!kIsWeb) {
      try {
        final tempDir = Directory.systemTemp.createTempSync('hydrated_bloc');
        HydratedBloc.storage = await HydratedStorage.build(
          storageDirectory: tempDir,
        );
      } catch (e) {
        dependencies.loggingService?.warning(
          'Falha ao configurar HydratedBloc storage: $e',
          tag: 'PaymentsMicroApp',
        );
      }
    }

    // Determinar se deve usar mock data
    final useMockData = dependencies.config.getValue<bool>('mock_data') ?? false;

    // Criar data source apropriado
    PaymentRemoteDataSource remoteDataSource;

    if (useMockData) {
      if (kDebugMode) {
        dependencies.loggingService?.info(
          'Using PaymentMockDataSource for development environment',
          tag: 'PaymentsMicroApp',
        );
      }
      remoteDataSource = PaymentMockDataSource();
    } else {
      remoteDataSource = PaymentRemoteDataSourceImpl(
        dependencies.networkService.createClient(
          baseUrl: dependencies.config.apiBaseUrl,
        ),
      );
    }

    // Criar repositório
    _paymentRepository = PaymentRepositoryImpl(
      remoteDataSource: remoteDataSource,
      authService: dependencies.authService,
    );

    // Criar cubit
    _paymentsCubit = PaymentsCubit(
      repository: _paymentRepository!,
      analyticsService: dependencies.analyticsService,
    );
  }

  @override
  Future<void> onDispose() async {
    if (_paymentsCubit != null) {
      try {
        await _paymentsCubit!.close();
      } catch (e) {
        dependencies.loggingService?.warning(
          'Erro ao fechar PaymentsCubit: $e',
          tag: 'PaymentsMicroApp',
        );
      } finally {
        _paymentsCubit = null;
      }
    }

    // Limpar repositório
    _paymentRepository = null;
  }

  @override
  Future<bool> checkHealth() async {
    if (_paymentsCubit == null || _paymentRepository == null) {
      return false;
    }

    try {
      // Verifica se o Cubit está em estado válido
      final state = _paymentsCubit!.state;
      return state != null;
    } catch (e) {
      dependencies.loggingService?.error(
        'Health check falhou para PaymentsCubit',
        error: e,
        tag: 'PaymentsMicroApp',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return flutter_bloc.BlocProvider<PaymentsCubit>(
      create: (context) => paymentsCubit,
      child: const PaymentsPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register<PaymentsCubit>(paymentsCubit);
  }
}
