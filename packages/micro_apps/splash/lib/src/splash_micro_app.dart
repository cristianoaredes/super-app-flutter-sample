import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';

import 'di/navigation_service_locator.dart';
import 'presentation/pages/splash_page.dart';


class SplashMicroApp implements MicroApp {
  bool _initialized = false;

  @override
  String get id => 'splash';

  @override
  String get name => 'Splash';

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) return;

    
    NavigationServiceLocator.setNavigationService(
        dependencies.navigationService);

    _initialized = true;
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
    
  }

  @override
  Future<void> dispose() async {
    
  }
}
