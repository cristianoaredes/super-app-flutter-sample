import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';


class ConsoleLogHandler implements LogHandler {
  final LogLevel _minLevel;
  
  
  ConsoleLogHandler({LogLevel minLevel = LogLevel.debug}) : _minLevel = minLevel;
  
  @override
  void handle(LogEntry entry) {
    if (kDebugMode) {
      final color = _getColorForLevel(entry.level);
      debugPrint('$color${entry.toString()}\x1B[0m');
    }
  }
  
  @override
  LogLevel get minLevel => _minLevel;
  
  String _getColorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '\x1B[37m'; 
      case LogLevel.info:
        return '\x1B[32m'; 
      case LogLevel.warning:
        return '\x1B[33m'; 
      case LogLevel.error:
        return '\x1B[31m'; 
      case LogLevel.fatal:
        return '\x1B[35m'; 
      default:
        return '';
    }
  }
}
