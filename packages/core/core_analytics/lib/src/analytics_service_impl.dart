import 'package:core_interfaces/core_interfaces.dart';

import 'models/analytics_event.dart';
import 'models/analytics_error.dart';
import 'providers/analytics_provider.dart';
import 'providers/console_analytics_provider.dart';


class AnalyticsServiceImpl implements AnalyticsService, CoreLibrary {
  final List<AnalyticsProvider> _providers = [];
  final LoggingService? _loggingService;

  String? _userId;
  Map<String, dynamic> _userProperties = {};
  bool _sessionActive = false;
  bool _initialized = false;

  AnalyticsServiceImpl({
    List<AnalyticsProvider>? providers,
    LoggingService? loggingService,
  }) : _loggingService = loggingService {
    
    if (providers != null) {
      _providers.addAll(providers);
    }

    
    _providers.add(ConsoleAnalyticsProvider());
  }

  @override
  String get id => 'core_analytics';

  @override
  Future<void> initialize(CoreLibraryDependencies dependencies) async {
    if (_initialized) return;

    
    for (final provider in _providers) {
      await provider.initialize();
    }

    _initialized = true;

    _loggingService?.info('AnalyticsService initialized',
        tag: 'AnalyticsService');
  }

  @override
  Future<void> trackEvent(
      String eventName, Map<String, dynamic> parameters) async {
    _ensureInitialized();

    final event = AnalyticsEvent(
      name: eventName,
      parameters: parameters,
      userId: _userId,
    );

    _loggingService?.debug(
      'Tracking event: ${event.name}',
      data: {
        'parameters': event.parameters,
        'userId': event.userId,
        'timestamp': event.timestamp.toIso8601String(),
      },
      tag: 'Analytics',
    );

    
    for (final provider in _providers) {
      await provider.trackEvent(event);
    }
  }

  @override
  Future<void> trackError(String errorName, String errorMessage,
      {StackTrace? stackTrace}) async {
    _ensureInitialized();

    final error = AnalyticsError(
      name: errorName,
      message: errorMessage,
      stackTrace: stackTrace,
      userId: _userId,
    );

    _loggingService?.error(
      'Tracking error: ${error.name}',
      error: error.message,
      stackTrace: error.stackTrace,
      data: {
        'userId': error.userId,
        'timestamp': error.timestamp.toIso8601String(),
      },
      tag: 'Analytics',
    );

    
    for (final provider in _providers) {
      await provider.trackError(error);
    }
  }

  @override
  Future<void> setUserId(String userId) async {
    _ensureInitialized();

    _userId = userId;

    _loggingService?.debug(
      'Setting user ID: $userId',
      tag: 'Analytics',
    );

    
    for (final provider in _providers) {
      await provider.setUserId(userId);
    }
  }

  @override
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    _ensureInitialized();

    _userProperties = properties;

    _loggingService?.debug(
      'Setting user properties',
      data: properties,
      tag: 'Analytics',
    );

    
    for (final provider in _providers) {
      await provider.setUserProperties(properties);
    }
  }

  @override
  Future<void> startSession() async {
    _ensureInitialized();

    _sessionActive = true;

    _loggingService?.debug(
      'Starting analytics session',
      data: {
        'userId': _userId,
      },
      tag: 'Analytics',
    );

    
    for (final provider in _providers) {
      await provider.startSession();
    }
  }

  @override
  Future<void> endSession() async {
    _ensureInitialized();

    _sessionActive = false;

    _loggingService?.debug(
      'Ending analytics session',
      data: {
        'userId': _userId,
      },
      tag: 'Analytics',
    );

    
    for (final provider in _providers) {
      await provider.endSession();
    }
  }

  
  void addProvider(AnalyticsProvider provider) async {
    _providers.add(provider);

    if (_initialized) {
      await provider.initialize();

      
      if (_userId != null) {
        await provider.setUserId(_userId!);
      }

      if (_userProperties.isNotEmpty) {
        await provider.setUserProperties(_userProperties);
      }

      if (_sessionActive) {
        await provider.startSession();
      }
    }
  }

  
  Future<void> removeProvider(AnalyticsProvider provider) async {
    _providers.remove(provider);
    await provider.dispose();
  }

  
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
          'AnalyticsService was not initialized. Call initialize() first.');
    }
  }

  @override
  Map<Type, Object> get services => {
        AnalyticsService: this,
      };

  @override
  List<BlocProvider> get globalBlocs => [];

  @override
  Future<void> dispose() async {
    if (_initialized) {
      
      if (_sessionActive) {
        await endSession();
      }

      
      for (final provider in _providers) {
        await provider.dispose();
      }

      _providers.clear();
      _initialized = false;

      _loggingService?.info('AnalyticsService disposed',
          tag: 'AnalyticsService');
    }
  }
}
