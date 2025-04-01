
abstract class NavigationService {
  
  Future<T?> navigateTo<T>(String route,
      {Map<String, String>? params, Map<String, String>? queryParams});

  
  Future<bool> navigateBack();

  
  Future<T?> replaceTo<T>(String route,
      {Map<String, String>? params, Map<String, String>? queryParams});

  
  Future<T?> clearStackAndNavigateTo<T>(String route,
      {Map<String, String>? params, Map<String, String>? queryParams});
}
