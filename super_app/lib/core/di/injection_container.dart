import 'package:account/account.dart';
import 'package:auth/auth.dart';
import 'package:cards/cards.dart';
import 'package:core_analytics/core_analytics.dart';
import 'package:core_interfaces/core_interfaces.dart' hide AppConfig;
import 'package:core_interfaces/core_interfaces.dart' as core_interfaces;
import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dashboard/dashboard.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:payments/payments.dart';
import 'package:flutter/material.dart';

import '../services/mock_analytics_service.dart';
import '../services/web_storage_service.dart';
import 'package:pix/pix.dart';
import 'package:splash/splash.dart';

import 'package:core_communication/core_communication.dart';
import 'package:core_feature_flags/core_feature_flags.dart';
import 'package:core_logging/core_logging.dart';
import 'package:core_navigation/core_navigation.dart';

import '../config/app_config.dart';
import '../services/auth_service_impl.dart';
import '../services/performance_monitor.dart';
import '../theme/app_theme.dart';
import '../theme/theme_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerLazySingleton<AppConfig>(
    () => AppConfig.development(),
  );

  sl.registerLazySingleton<core_interfaces.AppConfig>(
    () => core_interfaces.AppConfig(
      apiBaseUrl: 'https://api.dev.example.com/v1',
      appName: 'Banco Digital (Dev)',
      appVersion: '1.0.0',
      buildNumber: '1',
      environment: core_interfaces.Environment.development,
      additionalConfig: {
        'enable_logs': true,
        'mock_data': true,
      },
    ),
  );

  _registerCoreServices();

  _registerMicroApps();

  sl.registerLazySingleton(
    () => AppTheme.lightTheme,
    instanceName: 'lightTheme',
  );

  sl.registerLazySingleton(
    () => AppTheme.darkTheme,
    instanceName: 'darkTheme',
  );

  sl.registerFactory(
    () => ThemeBloc(),
  );
}

void _registerCoreServices() {
  sl.registerLazySingleton<NetworkService>(
    () => NetworkServiceImpl(),
  );

  sl.registerLazySingleton<StorageService>(
    () => kIsWeb ? WebStorageService() : StorageServiceImpl(),
  );

  if (kIsWeb) {
    sl.registerLazySingleton<AnalyticsService>(
      () => MockAnalyticsService(),
    );
  } else {
    sl.registerLazySingleton<AnalyticsService>(
      () => AnalyticsServiceImpl(),
    );
  }

  sl.registerLazySingleton<AuthService>(
    () => AuthServiceImpl(),
  );

  final navigationServiceImpl = NavigationServiceImpl();
  sl.registerLazySingleton<NavigationService>(
    () => navigationServiceImpl,
  );

  sl.registerLazySingleton<ApplicationHub>(
    () => ApplicationHubImpl(),
  );

  final loggingService = LoggingServiceImpl();
  loggingService.addHandler(ConsoleLogHandler());
  sl.registerLazySingleton<LoggingService>(
    () => loggingService,
  );

  sl.registerLazySingleton<FeatureFlagService>(
    () => FeatureFlagsServiceImpl(),
  );

  final performanceMonitor = PerformanceMonitor();
  try {
    performanceMonitor.initialize(
      analyticsService: sl<AnalyticsService>(),
      loggingService: sl<LoggingService>(),
      enabled: sl<core_interfaces.AppConfig>().environment !=
          core_interfaces.Environment.production,
    );
    loggingService.info('PerformanceMonitor inicializado com sucesso');
  } catch (e) {
    performanceMonitor.initialize(enabled: true);
    if (kDebugMode) {
      print('Erro ao inicializar PerformanceMonitor com dependências: $e');
    }
  }
  sl.registerLazySingleton<PerformanceMonitor>(
    () => performanceMonitor,
  );

  sl.registerLazySingleton<RouteObserver<ModalRoute<dynamic>>>(
    () => RouteObserver<ModalRoute<dynamic>>(),
  );
}

void _registerMicroApps() {
  sl.registerLazySingleton<MicroApp>(
    () => AccountMicroApp(),
    instanceName: 'account',
  );

  sl.registerLazySingleton<MicroApp>(
    () => AuthMicroApp(),
    instanceName: 'auth',
  );

  sl.registerLazySingleton<MicroApp>(
    () => CardsMicroApp(),
    instanceName: 'cards',
  );

  sl.registerLazySingleton<MicroApp>(
    () => DashboardMicroApp(),
    instanceName: 'dashboard',
  );

  sl.registerLazySingleton<MicroApp>(
    () => PaymentsMicroApp(),
    instanceName: 'payments',
  );

  sl.registerLazySingleton<MicroApp>(
    () => PixMicroApp(),
    instanceName: 'pix',
  );

  sl.registerLazySingleton<MicroApp>(
    () => SplashMicroApp(),
    instanceName: 'splash',
  );
}
