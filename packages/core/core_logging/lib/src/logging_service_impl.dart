import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';


class LoggingServiceImpl implements LoggingService {
  final List<LogHandler> _handlers = [];
  LogLevel _logLevel = LogLevel.info;
  final Map<String, dynamic> _globalMetadata = {};
  
  @override
  void debug(String message, {Map<String, dynamic>? data, String? tag}) {
    if (_logLevel.index <= LogLevel.debug.index) {
      _log(LogLevel.debug, message, data: data, tag: tag);
    }
  }
  
  @override
  void info(String message, {Map<String, dynamic>? data, String? tag}) {
    if (_logLevel.index <= LogLevel.info.index) {
      _log(LogLevel.info, message, data: data, tag: tag);
    }
  }
  
  @override
  void warning(String message, {Map<String, dynamic>? data, String? tag}) {
    if (_logLevel.index <= LogLevel.warning.index) {
      _log(LogLevel.warning, message, data: data, tag: tag);
    }
  }
  
  @override
  void error(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data, String? tag}) {
    if (_logLevel.index <= LogLevel.error.index) {
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace, data: data, tag: tag);
    }
  }
  
  @override
  void fatal(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data, String? tag}) {
    if (_logLevel.index <= LogLevel.fatal.index) {
      _log(LogLevel.fatal, message, error: error, stackTrace: stackTrace, data: data, tag: tag);
    }
  }
  
  @override
  set logLevel(LogLevel level) {
    _logLevel = level;
  }
  
  @override
  LogLevel get logLevel => _logLevel;
  
  @override
  void setGlobalMetadata(Map<String, dynamic> metadata) {
    _globalMetadata.clear();
    _globalMetadata.addAll(metadata);
  }
  
  @override
  void addHandler(LogHandler handler) {
    if (!_handlers.contains(handler)) {
      _handlers.add(handler);
    }
  }
  
  @override
  void removeHandler(LogHandler handler) {
    _handlers.remove(handler);
  }
  
  void _log(
    LogLevel level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    String? tag,
  }) {
    
    final mergedData = <String, dynamic>{};
    if (_globalMetadata.isNotEmpty) {
      mergedData.addAll(_globalMetadata);
    }
    if (data != null && data.isNotEmpty) {
      mergedData.addAll(data);
    }
    
    final entry = LogEntry(
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
      data: mergedData.isNotEmpty ? mergedData : null,
      tag: tag,
    );
    
    
    if (kDebugMode) {
      debugPrint(entry.toString());
    }
    
    
    for (final handler in _handlers) {
      if (level.index >= handler.minLevel.index) {
        handler.handle(entry);
      }
    }
  }
}
