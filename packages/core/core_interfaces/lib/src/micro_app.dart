import 'package:flutter/widgets.dart';

import 'bloc_registry.dart';
import 'application_hub/application_hub.dart';
import 'config/app_config.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'services/feature_flag_service.dart';
import 'services/logging_service.dart';
import 'services/navigation_service.dart';
import 'services/network_service.dart';
import 'services/storage_service.dart';


typedef GoRouteBuilder = Widget Function(
    BuildContext context, GoRouterState state);


class GoRouterState {
  final Map<String, String> params;
  final Map<String, String> queryParams;
  final String? path;

  GoRouterState({
    this.params = const {},
    this.queryParams = const {},
    this.path,
  });
}


abstract class MicroApp {
  
  String get id;

  
  String get name;

  
  Map<String, GoRouteBuilder> get routes;

  
  
  bool get isInitialized => true;

  
  Future<void> initialize(MicroAppDependencies dependencies);

  
  Widget build(BuildContext context);

  
  void registerBlocs(BlocRegistry registry);

  
  Future<void> dispose();
}


class MicroAppDependencies {
  final NavigationService navigationService;
  final AuthService authService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final NetworkService networkService;
  final AppConfig config;
  final ApplicationHub? applicationHub;
  final LoggingService? loggingService;
  final FeatureFlagService? featureFlagService;

  MicroAppDependencies({
    required this.navigationService,
    required this.authService,
    required this.storageService,
    required this.analyticsService,
    required this.networkService,
    required this.config,
    this.applicationHub,
    this.loggingService,
    this.featureFlagService,
  });
}
