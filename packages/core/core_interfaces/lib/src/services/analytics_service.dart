
abstract class AnalyticsService {
  
  Future<void> trackEvent(String eventName, Map<String, dynamic> parameters);

  
  Future<void> trackError(String errorName, String errorMessage,
      {StackTrace? stackTrace});

  
  Future<void> setUserId(String userId);

  
  Future<void> setUserProperties(Map<String, dynamic> properties);

  
  Future<void> startSession();

  
  Future<void> endSession();
}
