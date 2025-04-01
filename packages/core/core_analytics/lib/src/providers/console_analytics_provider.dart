import '../models/analytics_error.dart';
import '../models/analytics_event.dart';
import 'analytics_provider.dart';


class ConsoleAnalyticsProvider implements AnalyticsProvider {
  String? _userId;

  @override
  String get name => 'console';

  @override
  Future<void> initialize() async {
    print('📊 [Analytics] Initialized ConsoleAnalyticsProvider');
  }

  @override
  Future<void> trackEvent(AnalyticsEvent event) async {
    print('📊 [Analytics] Event: ${event.name}');
    print('  - Parameters: ${event.parameters}');
    print('  - Timestamp: ${event.timestamp}');
    print('  - User ID: ${event.userId ?? _userId ?? 'anonymous'}');
  }

  @override
  Future<void> trackError(AnalyticsError error) async {
    print('❌ [Analytics] Error: ${error.name}');
    print('  - Message: ${error.message}');
    print('  - Timestamp: ${error.timestamp}');
    print('  - User ID: ${error.userId ?? _userId ?? 'anonymous'}');

    if (error.stackTrace != null) {
      print('  - Stack Trace:');
      print(error.stackTrace);
    }
  }

  @override
  Future<void> setUserId(String userId) async {
    _userId = userId;
    print('👤 [Analytics] User ID set: $userId');
  }

  @override
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    print('👤 [Analytics] User properties set: $properties');
  }

  @override
  Future<void> startSession() async {
    print('🔄 [Analytics] Session started');
    print('  - User ID: ${_userId ?? 'anonymous'}');
  }

  @override
  Future<void> endSession() async {
    print('🔄 [Analytics] Session ended');
    print('  - User ID: ${_userId ?? 'anonymous'}');
  }

  @override
  Future<void> dispose() async {
    print('📊 [Analytics] Disposed ConsoleAnalyticsProvider');
  }
}
