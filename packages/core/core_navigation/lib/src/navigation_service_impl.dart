import 'package:core_interfaces/core_interfaces.dart';
import 'package:go_router/go_router.dart';


class NavigationServiceImpl implements NavigationService {
  late GoRouter _router;

  void setRouter(GoRouter router) {
    _router = router;
  }

  @override
  Future<bool> navigateBack() async {
    if (_router.canPop()) {
      _router.pop();
      return true;
    }
    return false;
  }

  @override
  Future<T?> navigateTo<T>(String route,
      {Map<String, String>? params, Map<String, String>? queryParams}) async {
    String finalRoute = route;

    
    if (params != null) {
      for (final entry in params.entries) {
        finalRoute = finalRoute.replaceAll(':${entry.key}', entry.value);
      }
    }

    
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      finalRoute = '$finalRoute?$queryString';
    }

    return _router.push<T>(finalRoute);
  }

  @override
  Future<T?> replaceTo<T>(String route,
      {Map<String, String>? params, Map<String, String>? queryParams}) async {
    String finalRoute = route;

    
    if (params != null) {
      for (final entry in params.entries) {
        finalRoute = finalRoute.replaceAll(':${entry.key}', entry.value);
      }
    }

    
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      finalRoute = '$finalRoute?$queryString';
    }

    return _router.replace<T>(finalRoute);
  }

  @override
  Future<T?> clearStackAndNavigateTo<T>(String route,
      {Map<String, String>? params, Map<String, String>? queryParams}) async {
    String finalRoute = route;

    
    if (params != null) {
      for (final entry in params.entries) {
        finalRoute = finalRoute.replaceAll(':${entry.key}', entry.value);
      }
    }

    
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      finalRoute = '$finalRoute?$queryString';
    }

    _router.go(finalRoute);
    return Future<T?>.value(null);
  }
}
