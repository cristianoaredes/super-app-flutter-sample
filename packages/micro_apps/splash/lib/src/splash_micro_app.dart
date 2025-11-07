import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';

import 'di/navigation_service_locator.dart';
import 'presentation/pages/splash_page.dart';

/// Micro app de Splash
///
/// Gerencia funcionalidades de:
/// - Tela inicial de carregamento
/// - Inicialização de serviços básicos
/// - Navegação inicial do app
class SplashMicroApp extends BaseMicroApp {
  SplashMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'splash';

  @override
  String get name => 'Splash';

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Configura o serviço de navegação para uso global
    NavigationServiceLocator.setNavigationService(
      dependencies.navigationService,
    );
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/': (context, state) => const SplashPage(),
      };

  @override
  Widget build(BuildContext context) {
    return const SplashPage();
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    // SplashMicroApp não possui BLoCs para registrar
  }

  @override
  Future<void> onDispose() async {
    // SplashMicroApp não possui recursos para limpar
  }

  @override
  Future<bool> checkHealth() async {
    // SplashMicroApp é sempre saudável (não possui estado para validar)
    return true;
  }
}
