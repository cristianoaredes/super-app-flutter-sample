import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/performance_monitor.dart';


class PerformanceObserver extends StatefulWidget {
  final Widget child;
  final String screenName;

  const PerformanceObserver({
    Key? key,
    required this.child,
    required this.screenName,
  }) : super(key: key);

  @override
  State<PerformanceObserver> createState() => _PerformanceObserverState();
}

class _PerformanceObserverState extends State<PerformanceObserver>
    with RouteAware {
  late final PerformanceMonitor _performanceMonitor;
  bool _isFirstBuild = true;
  bool _isMonitoringEnabled = false;

  @override
  void initState() {
    super.initState();
    _initMonitor();
  }

  void _initMonitor() {
    try {
      _performanceMonitor = GetIt.instance<PerformanceMonitor>();
      _isMonitoringEnabled = true;
      _startMeasurement();
    } catch (e) {
      _isMonitoringEnabled = false;
      print('Erro ao inicializar PerformanceObserver: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isMonitoringEnabled) return;

    try {
      
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        final routeObserver =
            GetIt.instance<RouteObserver<ModalRoute<dynamic>>>();
        routeObserver.subscribe(this, modalRoute);
      }
    } catch (e) {
      print('Erro ao registrar RouteObserver: $e');
    }
  }

  @override
  void dispose() {
    if (_isMonitoringEnabled) {
      try {
        
        final routeObserver =
            GetIt.instance<RouteObserver<ModalRoute<dynamic>>>();
        routeObserver.unsubscribe(this);
      } catch (e) {
        print('Erro ao desregistrar RouteObserver: $e');
      }
    }
    super.dispose();
  }

  @override
  void didPush() {
    
    if (_isMonitoringEnabled) {
      _startMeasurement();
    }
  }

  @override
  void didPopNext() {
    
    if (_isMonitoringEnabled) {
      _startMeasurement();
    }
  }

  void _startMeasurement() {
    if (!_isMonitoringEnabled) return;
    try {
      _performanceMonitor.startOperation('screen_render_${widget.screenName}');
    } catch (e) {
      print('Erro ao iniciar medição: $e');
    }
  }

  void _endMeasurement() {
    if (!_isMonitoringEnabled) return;
    try {
      _performanceMonitor.endOperation('screen_render_${widget.screenName}');
    } catch (e) {
      print('Erro ao finalizar medição: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    
    
    if (_isFirstBuild && _isMonitoringEnabled) {
      _isFirstBuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _endMeasurement();
      });
    }

    return widget.child;
  }
}


extension PerformanceObserverExtension on Widget {
  
  Widget withPerformanceMonitoring(String screenName) {
    return PerformanceObserver(
      screenName: screenName,
      child: this,
    );
  }
}
