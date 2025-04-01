import 'package:core_interfaces/core_interfaces.dart';

class AnalyticsServiceImpl implements AnalyticsService {
  String? _userId;
  bool _sessionActive = false;
  
  @override
  Future<void> trackEvent(String eventName, Map<String, dynamic> parameters) async {
    
    print('Analytics Event: $eventName, Parameters: $parameters, UserId: $_userId');
  }
  
  @override
  Future<void> trackError(String errorName, String errorMessage, {StackTrace? stackTrace}) async {
    
    print('Analytics Error: $errorName, Message: $errorMessage, UserId: $_userId');
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
  }
  
  @override
  Future<void> setUserId(String userId) async {
    _userId = userId;
    print('Analytics UserId set: $userId');
  }
  
  @override
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    print('Analytics User Properties: $properties, UserId: $_userId');
  }
  
  @override
  Future<void> startSession() async {
    _sessionActive = true;
    print('Analytics Session Started, UserId: $_userId, Session active: $_sessionActive');
  }
  
  @override
  Future<void> endSession() async {
    _sessionActive = false;
    print('Analytics Session Ended, UserId: $_userId, Session active: $_sessionActive');
  }
}
