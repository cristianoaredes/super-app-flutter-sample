
abstract class LoggingService {
  
  void debug(String message, {Map<String, dynamic>? data, String? tag});

  
  void info(String message, {Map<String, dynamic>? data, String? tag});

  
  void warning(String message, {Map<String, dynamic>? data, String? tag});

  
  void error(String message,
      {dynamic error,
      StackTrace? stackTrace,
      Map<String, dynamic>? data,
      String? tag});

  
  void fatal(String message,
      {dynamic error,
      StackTrace? stackTrace,
      Map<String, dynamic>? data,
      String? tag});

  
  set logLevel(LogLevel level);

  
  LogLevel get logLevel;

  
  void setGlobalMetadata(Map<String, dynamic> metadata);

  
  void addHandler(LogHandler handler);

  
  void removeHandler(LogHandler handler);
}


enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
  none,
}


abstract class LogHandler {
  
  void handle(LogEntry entry);

  
  LogLevel get minLevel;
}


class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final dynamic error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? data;
  final String? tag;

  LogEntry({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.data,
    this.tag,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[$level] ${timestamp.toIso8601String()} ');
    if (tag != null) {
      buffer.write('[$tag] ');
    }
    buffer.write(message);
    if (error != null) {
      buffer.write(' - Error: $error');
    }
    if (data != null && data!.isNotEmpty) {
      buffer.write(' - Data: $data');
    }
    if (stackTrace != null) {
      buffer.write('\nStackTrace: $stackTrace');
    }
    return buffer.toString();
  }
}
