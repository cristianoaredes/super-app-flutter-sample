import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../data/datasources/dashboard_remote_datasource.dart';
import '../data/datasources/dashboard_local_datasource.dart';
import '../data/datasources/dashboard_mock_datasource.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/usecases/get_account_summary_usecase.dart';
import '../domain/usecases/get_transaction_summary_usecase.dart';
import '../domain/usecases/get_quick_actions_usecase.dart';
import '../presentation/bloc/dashboard_bloc.dart';


class DashboardInjector {
  
  static void register(GetIt getIt) {
    
    if (kDebugMode) {
      print('🌐 Registrando DashboardRemoteDataSource');
    }

    
    final appConfig = getIt<AppConfig>();
    final useMockData = appConfig.getValue<bool>('mock_data') ?? false;

    if (kIsWeb || useMockData) {
      if (kDebugMode) {
        print(
            '🌐 Usando DashboardMockDataSource para ambiente ${kIsWeb ? 'web' : 'de desenvolvimento'}');
      }
      getIt.registerLazySingleton<DashboardRemoteDataSource>(
        () => DashboardMockDataSource(),
      );
    } else {
      getIt.registerLazySingleton<DashboardRemoteDataSource>(
        () => DashboardRemoteDataSourceImpl(
          apiClient: getIt<NetworkService>().createClient(
            baseUrl: appConfig.apiBaseUrl,
          ),
        ),
      );
    }

    getIt.registerLazySingleton<DashboardLocalDataSource>(
      () => DashboardLocalDataSourceImpl(
        storageService: getIt<StorageService>(),
      ),
    );

    
    getIt.registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(
        remoteDataSource: getIt<DashboardRemoteDataSource>(),
        localDataSource: getIt<DashboardLocalDataSource>(),
        networkService: getIt<NetworkService>(),
      ),
    );

    
    getIt.registerLazySingleton(
      () => GetAccountSummaryUseCase(
        repository: getIt<DashboardRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => GetTransactionSummaryUseCase(
        repository: getIt<DashboardRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => GetQuickActionsUseCase(
        repository: getIt<DashboardRepository>(),
      ),
    );

    
    getIt.registerFactory(
      () => DashboardBloc(
        getAccountSummaryUseCase: getIt<GetAccountSummaryUseCase>(),
        getTransactionSummaryUseCase: getIt<GetTransactionSummaryUseCase>(),
        getQuickActionsUseCase: getIt<GetQuickActionsUseCase>(),
        analyticsService: getIt<AnalyticsService>(),
      ),
    );
  }
}
