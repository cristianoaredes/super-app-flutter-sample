import 'package:core_interfaces/core_interfaces.dart';


class NavigationServiceLocator {
  static NavigationService? _navigationService;
  
  
  static void setNavigationService(NavigationService navigationService) {
    _navigationService = navigationService;
  }
  
  
  static NavigationService getNavigationService() {
    if (_navigationService == null) {
      throw Exception('NavigationService not set');
    }
    return _navigationService!;
  }
}
