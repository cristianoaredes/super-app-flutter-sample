import '../models/analytics_error.dart';
import '../models/analytics_event.dart';


abstract class AnalyticsProvider {
  
  String get name;

  
  Future<void> initialize();

  
  Future<void> trackEvent(AnalyticsEvent event);

  
  Future<void> trackError(AnalyticsError error);

  
  Future<void> setUserId(String userId);

  
  Future<void> setUserProperties(Map<String, dynamic> properties);

  
  Future<void> startSession();

  
  Future<void> endSession();

  
  Future<void> dispose();
}
