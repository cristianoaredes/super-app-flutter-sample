import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/material.dart';

import '../data/datasources/cards_remote_datasource.dart';
import '../data/datasources/cards_local_datasource.dart';
import '../data/datasources/cards_mock_datasource.dart';
import '../data/repositories/cards_repository_impl.dart';
import '../domain/repositories/cards_repository.dart';
import '../domain/usecases/get_cards_usecase.dart';
import '../domain/usecases/get_card_statement_usecase.dart';
import '../domain/usecases/block_card_usecase.dart';
import '../domain/usecases/unblock_card_usecase.dart';
import '../presentation/bloc/cards_bloc.dart';
import '../presentation/bloc/card_details_bloc.dart';

class CardsInjector {
  static void register(GetIt getIt) {
    if (kDebugMode) {
      print('🌐 Registrando CardsRemoteDataSource');
    }

    final appConfig = getIt<AppConfig>();
    final useMockData = appConfig.getValue<bool>('mock_data') ?? false;

    if (useMockData) {
      if (kDebugMode) {
        print('🌐 Usando CardsMockDataSource para ambiente de desenvolvimento');
      }
      getIt.registerLazySingleton<CardsRemoteDataSource>(
        () => CardsMockDataSource(),
      );
    } else {
      getIt.registerLazySingleton<CardsRemoteDataSource>(
        () => CardsRemoteDataSourceImpl(
          apiClient: getIt<NetworkService>().createClient(
            baseUrl: appConfig.apiBaseUrl,
          ),
        ),
      );
    }

    getIt.registerLazySingleton<CardsLocalDataSource>(
      () => CardsLocalDataSourceImpl(
        storageService: getIt<StorageService>(),
      ),
    );

    getIt.registerLazySingleton<CardsRepository>(
      () => CardsRepositoryImpl(
        remoteDataSource: getIt<CardsRemoteDataSource>(),
        localDataSource: getIt<CardsLocalDataSource>(),
        networkService: getIt<NetworkService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => GetCardsUseCase(
        repository: getIt<CardsRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => GetCardStatementUseCase(
        repository: getIt<CardsRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => BlockCardUseCase(
        repository: getIt<CardsRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => UnblockCardUseCase(
        repository: getIt<CardsRepository>(),
      ),
    );

    // Registra o CardsBloc como singleton
    if (!getIt.isRegistered<CardsBloc>()) {
      getIt.registerLazySingleton<CardsBloc>(
        () => CardsBloc(
          getCardsUseCase: getIt<GetCardsUseCase>(),
          analyticsService: getIt<AnalyticsService>(),
        ),
      );
    }

    // Registra o CardDetailsBloc como factory (nova instância para cada detalhe)
    getIt.registerFactory<CardDetailsBloc>(
      () => CardDetailsBloc(
        getCardsUseCase: getIt<GetCardsUseCase>(),
        getCardStatementUseCase: getIt<GetCardStatementUseCase>(),
        blockCardUseCase: getIt<BlockCardUseCase>(),
        unblockCardUseCase: getIt<UnblockCardUseCase>(),
        analyticsService: getIt<AnalyticsService>(),
      ),
    );

    // RouteObserver
    if (!getIt.isRegistered<RouteObserver<ModalRoute<void>>>()) {
      getIt.registerLazySingleton<RouteObserver<ModalRoute<void>>>(
        () => RouteObserver<ModalRoute<void>>(),
      );
    }
  }
}
