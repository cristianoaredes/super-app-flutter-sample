import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../data/datasources/auth_remote_datasource.dart';
import '../data/datasources/auth_local_datasource.dart';
import '../data/datasources/auth_mock_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/logout_usecase.dart';
import '../domain/usecases/register_usecase.dart';
import '../domain/usecases/reset_password_usecase.dart';
import '../presentation/bloc/auth_bloc.dart';


class AuthInjector {
  
  static void register(GetIt getIt) {
    
    if (kDebugMode) {
      print('🌐 Registering AuthRemoteDataSource');
    }

    
    final appConfig = getIt<AppConfig>();
    final useMockData = appConfig.getValue<bool>('mock_data') ?? false;

    if (useMockData) {
      if (kDebugMode) {
        print('🌐 Using AuthMockDataSource for development environment');
      }
      getIt.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthMockDataSource(),
      );
    } else {
      getIt.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(
          apiClient: getIt<NetworkService>().createClient(
            baseUrl: appConfig.apiBaseUrl,
            authService: getIt<AuthService>(),
          ),
        ),
      );
    }

    getIt.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(
        storageService: getIt<StorageService>(),
      ),
    );

    
    getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: getIt<AuthRemoteDataSource>(),
        localDataSource: getIt<AuthLocalDataSource>(),
        networkService: getIt<NetworkService>(),
      ),
    );

    
    getIt.registerLazySingleton(
      () => LoginUseCase(
        repository: getIt<AuthRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => LogoutUseCase(
        repository: getIt<AuthRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => RegisterUseCase(
        repository: getIt<AuthRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ResetPasswordUseCase(
        repository: getIt<AuthRepository>(),
      ),
    );

    
    getIt.registerFactory(
      () => AuthBloc(
        loginUseCase: getIt<LoginUseCase>(),
        logoutUseCase: getIt<LogoutUseCase>(),
        registerUseCase: getIt<RegisterUseCase>(),
        resetPasswordUseCase: getIt<ResetPasswordUseCase>(),
        analyticsService: getIt<AnalyticsService>(),
      ),
    );
  }
}
