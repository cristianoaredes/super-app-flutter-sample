import 'package:core_interfaces/core_interfaces.dart' as core_interfaces;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:splash/splash.dart';
import '../widgets/app_shell.dart';
import '../widgets/error_page.dart';
import 'route_middleware.dart';

core_interfaces.GoRouterState _adaptGoRouterState(GoRouterState state) {
  return core_interfaces.GoRouterState(
    params: state.pathParameters,
    queryParams: state.uri.queryParameters,
    path: state.matchedLocation,
  );
}

class AppRouter {
  final GetIt _getIt;
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  final List<NavigatorObserver> _observers;
  late final MicroAppInitializerMiddleware _microAppInitializer;

  AppRouter({
    required GetIt getIt,
    List<NavigatorObserver>? observers,
  })  : _getIt = getIt,
        _observers = observers ?? [] {
    _microAppInitializer = MicroAppInitializerMiddleware(getIt: _getIt);
  }

  GoRouter get router => _createRouter();

  void setObservers(List<NavigatorObserver> observers) {
    _observers.clear();
    _observers.addAll(observers);
  }

  GoRouter _createRouter() {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/',
      debugLogDiagnostics: true,
      redirect: _microAppInitializer.redirect,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: '/error',
          builder: (context, state) => const ErrorPage(),
        ),
        ..._getMicroAppRoutes(),
      ],
      errorBuilder: _buildErrorPage,
      observers: _observers,
    );
  }

  Widget _buildErrorPage(BuildContext context, GoRouterState state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Página não encontrada'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64.0,
              color: Colors.red,
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Página não encontrada',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'A rota ${state.uri.path} não existe',
              style: const TextStyle(
                fontSize: 16.0,
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: () => _navigateToHome(context),
              child: const Text('Voltar para o início'),
            ),
          ],
        ),
      ),
    );
  }

  List<RouteBase> _getMicroAppRoutes() {
    final routes = <RouteBase>[];

    final microApps = _getMicroApps();

    for (final microApp in microApps) {
      final microAppRoutes = microApp.routes;

      for (final entry in microAppRoutes.entries) {
        final path = entry.key;
        final builder = entry.value;

        final bool isAuthRoute = path == '/login' ||
            path == '/register' ||
            path == '/reset-password';

        routes.add(
          GoRoute(
            path: path,
            builder: (context, state) {
              final widget = builder(context, _adaptGoRouterState(state));

              if (isAuthRoute) {
                return widget;
              }

              return AppShell(child: widget);
            },
          ),
        );
      }
    }

    return routes;
  }

  List<core_interfaces.MicroApp> _getMicroApps() {
    return [
      _getIt<core_interfaces.MicroApp>(instanceName: 'account'),
      _getIt<core_interfaces.MicroApp>(instanceName: 'auth'),
      _getIt<core_interfaces.MicroApp>(instanceName: 'cards'),
      _getIt<core_interfaces.MicroApp>(instanceName: 'dashboard'),
      _getIt<core_interfaces.MicroApp>(instanceName: 'payments'),
      _getIt<core_interfaces.MicroApp>(instanceName: 'pix'),
      _getIt<core_interfaces.MicroApp>(instanceName: 'splash'),
    ];
  }

  void _navigateToHome(BuildContext context) {
    GoRouter.of(context).go('/dashboard');
  }
}
