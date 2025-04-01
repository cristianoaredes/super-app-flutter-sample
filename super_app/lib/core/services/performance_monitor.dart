import 'dart:collection';
import 'dart:developer' as developer;

import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';


class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();

  factory PerformanceMonitor() => _instance;

  PerformanceMonitor._internal()
      : _analyticsService = null,
        _loggingService = null;

  AnalyticsService? _analyticsService;
  LoggingService? _loggingService;

  bool _isInitialized = false;
  bool _isEnabled = true;

  
  final Map<String, DateTime> _startTimes = {};

  
  final Map<String, Queue<int>> _metrics = {};
  final int _maxMetricsHistory = 20;

  
  void initialize({
    AnalyticsService? analyticsService,
    LoggingService? loggingService,
    bool enabled = true,
  }) {
    if (_isInitialized) return;

    _analyticsService = analyticsService;
    _loggingService = loggingService;
    _isEnabled = enabled;
    _isInitialized = true;

    log('PerformanceMonitor inicializado: ${enabled ? "ativado" : "desativado"}');
  }

  
  void startOperation(String operationName) {
    if (!_isEnabled) return;

    _startTimes[operationName] = DateTime.now();
    log('Iniciando operação: $operationName');
  }

  
  void endOperation(String operationName, {bool sendToAnalytics = true}) {
    if (!_isEnabled) return;

    final startTime = _startTimes[operationName];
    if (startTime == null) {
      log('Operação não iniciada: $operationName', level: LogLevel.warning);
      return;
    }

    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;

    
    if (!_metrics.containsKey(operationName)) {
      _metrics[operationName] = Queue<int>();
    }

    final metricsQueue = _metrics[operationName]!;
    metricsQueue.add(durationMs);

    
    while (metricsQueue.length > _maxMetricsHistory) {
      metricsQueue.removeFirst();
    }

    
    final avg = _calculateAverage(metricsQueue.toList());

    log('Operação concluída: $operationName, duração: ${durationMs}ms, média: ${avg.toStringAsFixed(1)}ms');

    
    if (sendToAnalytics && _analyticsService != null) {
      try {
        _analyticsService!.trackEvent(
          'performance_metric',
          {
            'operation': operationName,
            'duration_ms': durationMs,
            'average_ms': avg,
          },
        );
      } catch (e) {
        log('Erro ao enviar métrica para analytics: $e', level: LogLevel.error);
      }
    }

    
    _startTimes.remove(operationName);
  }

  
  int measureSync(String operationName, Function operation) {
    if (!_isEnabled) {
      operation();
      return 0;
    }

    final startTime = DateTime.now();
    operation();
    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;

    log('Operação síncrona: $operationName, duração: ${durationMs}ms');

    return durationMs;
  }

  
  Future<int> measureAsync(
      String operationName, Future Function() operation) async {
    if (!_isEnabled) {
      await operation();
      return 0;
    }

    final startTime = DateTime.now();
    await operation();
    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;

    log('Operação assíncrona: $operationName, duração: ${durationMs}ms');

    return durationMs;
  }

  
  void logMemoryInfo() {
    if (!_isEnabled) return;

    
    if (kDebugMode) {
      try {
        developer.Timeline.startSync('MemoryUsage');

        
        final info = PlatformDispatcher.instance;
        final textScaleFactor = info.textScaleFactor;
        final devicePixelRatio =
            WidgetsBinding.instance.window.devicePixelRatio;

        log('Informações de plataforma - Escala de texto: $textScaleFactor, Escala de pixels: $devicePixelRatio');

        developer.Timeline.finishSync();
      } catch (e) {
        log('Erro ao obter informações de memória: $e', level: LogLevel.error);
      }
    }
  }

  
  double _calculateAverage(List<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  
  Map<String, dynamic> getOperationStats(String operationName) {
    if (!_metrics.containsKey(operationName)) {
      return {'count': 0};
    }

    final values = _metrics[operationName]!.toList();
    values.sort();

    final count = values.length;
    final min = count > 0 ? values.first : 0;
    final max = count > 0 ? values.last : 0;
    final avg = _calculateAverage(values);

    
    final p50 = count > 5 ? values[(count * 0.5).floor()] : 0;
    final p90 = count > 10 ? values[(count * 0.9).floor()] : 0;
    final p95 = count > 20 ? values[(count * 0.95).floor()] : 0;

    return {
      'count': count,
      'min': min,
      'max': max,
      'avg': avg,
      'p50': p50,
      'p90': p90,
      'p95': p95,
    };
  }

  
  String generatePerformanceReport() {
    if (!_isEnabled || _metrics.isEmpty) {
      return 'Nenhuma métrica de performance disponível.';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== Relatório de Performance ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    
    final operations = _metrics.keys.toList();
    operations.sort((a, b) {
      final statsA = getOperationStats(a);
      final statsB = getOperationStats(b);
      return (statsB['avg'] as double).compareTo(statsA['avg'] as double);
    });

    
    for (final op in operations) {
      final stats = getOperationStats(op);
      buffer.writeln('Operação: $op');
      buffer.writeln('  Contagem: ${stats['count']}');
      buffer.writeln('  Média: ${stats['avg'].toStringAsFixed(1)}ms');
      buffer.writeln('  Min/Max: ${stats['min']}ms / ${stats['max']}ms');
      buffer.writeln(
          '  P50/P90/P95: ${stats['p50']}ms / ${stats['p90']}ms / ${stats['p95']}ms');
      buffer.writeln();
    }

    return buffer.toString();
  }

  
  void log(String message, {LogLevel level = LogLevel.debug}) {
    if (!_isEnabled) return;

    switch (level) {
      case LogLevel.debug:
        _loggingService?.debug(message, tag: 'Performance');
        break;
      case LogLevel.info:
        _loggingService?.info(message, tag: 'Performance');
        break;
      case LogLevel.warning:
        _loggingService?.warning(message, tag: 'Performance');
        break;
      case LogLevel.error:
        _loggingService?.error(message, tag: 'Performance');
        break;
      case LogLevel.fatal:
        _loggingService?.error('FATAL: $message', tag: 'Performance');
        break;
      case LogLevel.none:
        
        break;
    }

    if (kDebugMode) {
      print('[Performance] $message');
    }
  }
}
