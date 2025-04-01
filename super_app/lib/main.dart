import 'package:core_interfaces/core_interfaces.dart'
    hide BlocProvider, AppConfig;
import 'package:core_interfaces/core_interfaces.dart' as core_interfaces;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pix/pix.dart';
import 'package:get_it/get_it.dart';

import 'core/di/injection_container.dart' as di;
import 'core/router/app_router.dart';
import 'core/theme/theme_bloc.dart';
import 'package:core_navigation/core_navigation.dart';

final getIt = GetIt.instance;

final blocRegistry = core_interfaces.BlocRegistry();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await di.init();

  await _initializeCoreServices();

  final dependencies = MicroAppDependencies(
    navigationService: getIt<NavigationService>(),
    analyticsService: getIt<AnalyticsService>(),
    storageService: getIt<StorageService>(),
    networkService: getIt<NetworkService>(),
    authService: getIt<AuthService>(),
    config: getIt<core_interfaces.AppConfig>(),
    applicationHub: getIt<ApplicationHub>(),
    loggingService: getIt<LoggingService>(),
    featureFlagService: getIt<FeatureFlagService>(),
  );

  await _initializeMicroApps(dependencies);

  _registerMicroAppBlocs();

  runApp(const SuperApp());
}

Future<void> _initializeCoreServices() async {
  LoggingService? logService;
  try {
    logService = getIt<LoggingService>();
    logService.info('Iniciando serviços core em paralelo');
  } catch (e) {
    if (kDebugMode) {
      print('Erro ao obter LoggingService: $e');
    }
  }

  final initializedServices = <String>[];

  void safeLog(String message, {LogLevel level = LogLevel.info}) {
    if (logService != null) {
      try {
        switch (level) {
          case LogLevel.debug:
            logService.debug(message);
            break;
          case LogLevel.info:
            logService.info(message);
            break;
          case LogLevel.warning:
            logService.warning(message);
            break;
          case LogLevel.error:
            logService.error(message);
            break;
          default:
            logService.info(message);
            break;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Erro ao registrar log: $e');
          print(message);
        }
      }
    } else if (kDebugMode) {
      print(message);
    }
  }

  try {
    await Future.wait([
      getIt<StorageService>().initialize().then((_) {
        initializedServices.add('storage');
        safeLog('Serviço de storage inicializado');
      }).catchError((e) {
        safeLog('Erro ao inicializar storage: $e', level: LogLevel.error);
      }),
      _initializeFeatureFlags().then((_) {
        initializedServices.add('feature_flags');
        safeLog('Feature flags inicializadas');
      }).catchError((e) {
        safeLog('Erro ao inicializar feature flags: $e', level: LogLevel.error);
      }),
    ]);

    if (initializedServices.contains('storage')) {
      try {
        final analyticsService = getIt<AnalyticsService>();
        if (analyticsService is CoreLibrary) {
          await (analyticsService as CoreLibrary)
              .initialize(CoreLibraryDependencies(
            config: getIt<core_interfaces.AppConfig>(),
            services: {
              if (logService != null) LoggingService: logService,
              StorageService: getIt<StorageService>(),
            },
          ));
          initializedServices.add('analytics');
          safeLog('Serviço de analytics inicializado');
        } else {
          safeLog('AnalyticsService não é uma instância de CoreLibrary',
              level: LogLevel.warning);
        }
      } catch (e) {
        safeLog('Erro ao inicializar analytics: $e', level: LogLevel.error);
      }
    } else {
      safeLog(
          'Não foi possível inicializar analytics porque storage não foi inicializado',
          level: LogLevel.warning);
    }

    safeLog(
        'Inicialização dos serviços core finalizada. Serviços inicializados: ${initializedServices.join(", ")}');
  } catch (e) {
    safeLog('Erro geral ao inicializar serviços core: $e',
        level: LogLevel.error);
    if (kDebugMode) {
      print('Erro ao inicializar serviços core: $e');
    }
  }
}

Future<void> _initializeFeatureFlags() async {
  try {
    final featureFlagService = getIt<FeatureFlagService>();
    final logService = getIt<LoggingService>();

    if (featureFlagService is CoreLibrary) {
      try {
        await (featureFlagService as CoreLibrary)
            .initialize(CoreLibraryDependencies(
          config: getIt<core_interfaces.AppConfig>(),
          services: {
            LoggingService: logService,
          },
        ));
        logService.info('Feature flags inicializadas com sucesso');
      } catch (e) {
        logService.error('Erro ao inicializar feature flags: $e');
      }
    } else {
      logService
          .warning('FeatureFlagService não é uma instância de CoreLibrary');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Erro ao acessar serviços para feature flags: $e');
    }
  }
}

Future<void> _initializeMicroApps(MicroAppDependencies dependencies) async {
  final loggingService = getIt<LoggingService>();

  try {
    loggingService.info('Inicializando micro apps essenciais');

    final splashMicroApp = getIt<MicroApp>(instanceName: 'splash');
    await splashMicroApp.initialize(dependencies);

    final authMicroApp = getIt<MicroApp>(instanceName: 'auth');
    await authMicroApp.initialize(dependencies);

    getIt.registerLazySingleton<Future<void> Function(String)>(
      () => (String microAppName) async {
        final microApp = getIt<MicroApp>(instanceName: microAppName);
        final loggingService = getIt<LoggingService>();

        if (microApp.isInitialized) {
          try {
            if (microAppName == 'payments') {
              try {
                (microApp as dynamic).paymentsCubit;
                loggingService.info(
                    'Micro app $microAppName já estava inicializado e é válido');
                return;
              } catch (e) {
                loggingService.warning(
                    'PaymentsCubit não está em um estado válido, reinicializando: $e');
                await microApp.dispose();
              }
            } else if (microAppName == 'pix') {
              try {
                (microApp as dynamic).pixBloc;
                loggingService.info(
                    'Micro app $microAppName já estava inicializado e é válido');
                return;
              } catch (e) {
                loggingService.warning(
                    'PixBloc não está em um estado válido, reinicializando: $e');
                await microApp.dispose();
              }
            } else {
              loggingService
                  .info('Micro app $microAppName já estava inicializado');
              return;
            }
          } catch (e) {
            loggingService.warning(
                'Erro ao verificar estado do $microAppName, reinicializando: $e');
            try {
              await microApp.dispose();
            } catch (disposeError) {
              loggingService
                  .error('Erro ao descartar $microAppName: $disposeError');
            }
          }
        }

        loggingService
            .info('Inicializando micro app sob demanda: $microAppName');

        try {
          final dependencies = MicroAppDependencies(
            navigationService: getIt<NavigationService>(),
            analyticsService: getIt<AnalyticsService>(),
            storageService: getIt<StorageService>(),
            networkService: getIt<NetworkService>(),
            authService: getIt<AuthService>(),
            config: getIt<core_interfaces.AppConfig>(),
            applicationHub: getIt<ApplicationHub>(),
            loggingService: getIt<LoggingService>(),
            featureFlagService: getIt<FeatureFlagService>(),
          );

          await microApp.initialize(dependencies);

          microApp.registerBlocs(blocRegistry);

          loggingService
              .info('Micro app $microAppName inicializado com sucesso');
        } catch (e) {
          loggingService.error('Falha ao inicializar $microAppName: $e');
          throw Exception('Falha ao inicializar $microAppName: $e');
        }

        return;
      },
      instanceName: 'initializeMicroApp',
    );
  } catch (e) {
    loggingService.error('Erro ao inicializar micro apps: $e');
  }
}

void _registerMicroAppBlocs() {
  getIt.registerSingleton<core_interfaces.BlocRegistry>(blocRegistry);

  final splashMicroApp = getIt<MicroApp>(instanceName: 'splash');
  splashMicroApp.registerBlocs(blocRegistry);

  final authMicroApp = getIt<MicroApp>(instanceName: 'auth');
  authMicroApp.registerBlocs(blocRegistry);
}

class SuperApp extends StatefulWidget {
  const SuperApp({super.key});

  @override
  State<SuperApp> createState() => _SuperAppState();
}

class _SuperAppState extends State<SuperApp> {
  late final router = AppRouter(
    getIt: getIt,
    observers: [
      getIt<RouteObserver<ModalRoute<dynamic>>>(),
    ],
  ).router;

  @override
  void initState() {
    super.initState();

    final navigationService = getIt<NavigationService>();
    if (navigationService is NavigationServiceImpl) {
      navigationService.setRouter(router);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocProviders = <BlocProvider>[];

    blocProviders.add(
      BlocProvider<ThemeBloc>(
        create: (context) => getIt<ThemeBloc>(),
      ),
    );

    if (blocRegistry.contains<PixBloc>()) {
      blocProviders.add(
        BlocProvider<PixBloc>.value(
          value: blocRegistry.get<PixBloc>()!,
        ),
      );
    }

    return MultiBlocProvider(
      providers: blocProviders,
      child: BlocBuilder<ThemeBloc, dynamic>(
        builder: (context, state) {
          return MaterialApp.router(
            title: 'Super App - Arquitetura Modular',
            theme: getIt(instanceName: 'lightTheme'),
            darkTheme: getIt(instanceName: 'darkTheme'),
            themeMode: ThemeMode.dark,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
