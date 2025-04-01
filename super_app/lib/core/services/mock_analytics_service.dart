import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';


class MockAnalyticsService implements AnalyticsService, CoreLibrary {
  
  final String _id = 'mock_analytics_service';
  final Map<Type, Object> _services = {};
  final List<BlocProvider> _globalBlocs = [];

  @override
  String get id => _id;

  @override
  Map<Type, Object> get services => _services;

  @override
  List<BlocProvider> get globalBlocs => _globalBlocs;

  @override
  Future<void> initialize([CoreLibraryDependencies? dependencies]) async {
    if (kDebugMode) {
      print('MockAnalyticsService initialized');
    }
  }

  @override
  Future<void> dispose() async {
    if (kDebugMode) {
      print('MockAnalyticsService disposed');
    }
  }

  @override
  Future<void> trackEvent(
      String eventName, Map<String, dynamic> properties) async {
    if (kDebugMode) {
      print('MockAnalyticsService.trackEvent: $eventName, $properties');
    }
  }

  @override
  Future<void> trackError(String errorName, String errorMessage,
      {StackTrace? stackTrace}) async {
    if (kDebugMode) {
      print('MockAnalyticsService.trackError: $errorName, $errorMessage');
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }
  }

  
  Future<void> trackScreen(
      String screenName, Map<String, dynamic> properties) async {
    if (kDebugMode) {
      print('MockAnalyticsService.trackScreen: $screenName, $properties');
    }
  }

  
  Future<void> setUserProperty(String propertyName, dynamic value) async {
    if (kDebugMode) {
      print('MockAnalyticsService.setUserProperty: $propertyName, $value');
    }
  }

  @override
  Future<void> setUserId(String userId) async {
    if (kDebugMode) {
      print('MockAnalyticsService.setUserId: $userId');
    }
  }

  @override
  Future<void> startSession() async {
    if (kDebugMode) {
      print('MockAnalyticsService.startSession');
    }
  }

  @override
  Future<void> endSession() async {
    if (kDebugMode) {
      print('MockAnalyticsService.endSession');
    }
  }

  @override
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    if (kDebugMode) {
      print('MockAnalyticsService.setUserProperties: $properties');
    }
  }
}
