import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../data/datasources/pix_remote_datasource.dart';
import '../data/datasources/pix_local_datasource.dart';
import '../data/datasources/pix_mock_datasource.dart';
import '../data/repositories/pix_repository_impl.dart';
import '../domain/repositories/pix_repository.dart';
import '../domain/usecases/get_pix_keys_usecase.dart';
import '../domain/usecases/register_pix_key_usecase.dart';
import '../domain/usecases/delete_pix_key_usecase.dart';
import '../domain/usecases/send_pix_usecase.dart';
import '../domain/usecases/receive_pix_usecase.dart';
import '../domain/usecases/generate_qr_code_usecase.dart';
import '../domain/usecases/read_qr_code_usecase.dart';
import '../presentation/bloc/pix_bloc.dart';

class PixInjector {
  static void register(GetIt getIt) {
    if (kDebugMode) {
      print('🌐 Registrando PixRemoteDataSource');
    }

    final appConfig = getIt<AppConfig>();
    final useMockData = appConfig.getValue<bool>('mock_data') ?? false;

    if (useMockData) {
      if (kDebugMode) {
        print('🌐 Usando PixMockDataSource para ambiente de desenvolvimento');
      }
      getIt.registerLazySingleton<PixRemoteDataSource>(
        () => PixMockDataSource(),
      );
    } else {
      getIt.registerLazySingleton<PixRemoteDataSource>(
        () => PixRemoteDataSourceImpl(
          apiClient: getIt<NetworkService>().createClient(
            baseUrl: appConfig.apiBaseUrl,
          ),
        ),
      );
    }

    getIt.registerLazySingleton<PixLocalDataSource>(
      () => PixLocalDataSourceImpl(
        storageService: getIt<StorageService>(),
      ),
    );

    getIt.registerLazySingleton<PixRepository>(
      () => PixRepositoryImpl(
        remoteDataSource: getIt<PixRemoteDataSource>(),
        localDataSource: getIt<PixLocalDataSource>(),
        networkService: getIt<NetworkService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => GetPixKeysUseCase(
        repository: getIt<PixRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => RegisterPixKeyUseCase(
        repository: getIt<PixRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => DeletePixKeyUseCase(
        repository: getIt<PixRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => SendPixUseCase(
        repository: getIt<PixRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ReceivePixUseCase(
        repository: getIt<PixRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => GenerateQrCodeUseCase(
        repository: getIt<PixRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ReadQrCodeUseCase(
        repository: getIt<PixRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => PixBloc(
        getPixKeysUseCase: getIt<GetPixKeysUseCase>(),
        registerPixKeyUseCase: getIt<RegisterPixKeyUseCase>(),
        deletePixKeyUseCase: getIt<DeletePixKeyUseCase>(),
        sendPixUseCase: getIt<SendPixUseCase>(),
        receivePixUseCase: getIt<ReceivePixUseCase>(),
        generateQrCodeUseCase: getIt<GenerateQrCodeUseCase>(),
        readQrCodeUseCase: getIt<ReadQrCodeUseCase>(),
        analyticsService: getIt<AnalyticsService>(),
      ),
    );
  }
}
