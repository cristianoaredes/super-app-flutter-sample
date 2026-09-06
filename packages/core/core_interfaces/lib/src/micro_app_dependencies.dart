/// Declaração das dependências injetadas em cada micro app durante a
/// inicialização.
///
/// Contém apenas declarações (campos e construtor), sem nenhuma lógica de
/// runtime. A API permanece compatível com os consumidores existentes
/// (super app e micro apps), que a recebem via barrel `core_interfaces.dart`.
library micro_app_dependencies;

import 'application_hub/application_hub.dart';
import 'config/app_config.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'services/feature_flag_service.dart';
import 'services/logging_service.dart';
import 'services/navigation_service.dart';
import 'services/network_service.dart';
import 'services/storage_service.dart';

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
