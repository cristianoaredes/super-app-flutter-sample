import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../data/datasources/account_remote_datasource.dart';
import '../data/datasources/account_local_datasource.dart';
import '../data/datasources/account_mock_datasource.dart';
import '../data/repositories/account_repository_impl.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/usecases/get_account_usecase.dart';
import '../domain/usecases/get_account_balance_usecase.dart';
import '../domain/usecases/get_account_statement_usecase.dart';
import '../domain/usecases/transfer_money_usecase.dart';
import '../presentation/bloc/account_bloc.dart';


class AccountInjector {
  
  static void register(GetIt getIt) {
    
    if (kDebugMode) {
      print('🌐 Registrando AccountRemoteDataSource');
    }

    
    final appConfig = getIt<AppConfig>();
    final useMockData = appConfig.getValue<bool>('mock_data') ?? false;

    if (useMockData) {
      if (kDebugMode) {
        print(
            '🌐 Usando AccountMockDataSource para ambiente de desenvolvimento');
      }
      getIt.registerLazySingleton<AccountRemoteDataSource>(
        () => AccountMockDataSource(),
      );
    } else {
      getIt.registerLazySingleton<AccountRemoteDataSource>(
        () => AccountRemoteDataSourceImpl(
          apiClient: getIt<NetworkService>().createClient(
            baseUrl: appConfig.apiBaseUrl,
            authService: getIt<AuthService>(),
          ),
        ),
      );
    }

    getIt.registerLazySingleton<AccountLocalDataSource>(
      () => AccountLocalDataSourceImpl(
        storageService: getIt<StorageService>(),
      ),
    );

    
    getIt.registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        remoteDataSource: getIt<AccountRemoteDataSource>(),
        localDataSource: getIt<AccountLocalDataSource>(),
        networkService: getIt<NetworkService>(),
      ),
    );

    
    getIt.registerLazySingleton(
      () => GetAccountUseCase(
        repository: getIt<AccountRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => GetAccountBalanceUseCase(
        repository: getIt<AccountRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => GetAccountStatementUseCase(
        repository: getIt<AccountRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => TransferMoneyUseCase(
        repository: getIt<AccountRepository>(),
      ),
    );

    
    getIt.registerFactory(
      () => AccountBloc(
        getAccountUseCase: getIt<GetAccountUseCase>(),
        getAccountBalanceUseCase: getIt<GetAccountBalanceUseCase>(),
        getAccountStatementUseCase: getIt<GetAccountStatementUseCase>(),
        transferMoneyUseCase: getIt<TransferMoneyUseCase>(),
        analyticsService: getIt<AnalyticsService>(),
      ),
    );
  }
}
