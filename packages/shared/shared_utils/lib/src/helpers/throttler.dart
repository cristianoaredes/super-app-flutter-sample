import 'dart:async';

import 'package:flutter/foundation.dart';


class Throttler {
  final Duration duration;
  Timer? _timer;
  bool _isReady = true;
  
  Throttler({this.duration = const Duration(milliseconds: 300)});
  
  
  void run(VoidCallback action) {
    if (_isReady) {
      _isReady = false;
      action();
      _timer = Timer(duration, () {
        _isReady = true;
      });
    }
  }
  
  
  void runWithParams<T>(void Function(T) action, T param) {
    if (_isReady) {
      _isReady = false;
      action(param);
      _timer = Timer(duration, () {
        _isReady = true;
      });
    }
  }
  
  
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _isReady = true;
  }
  
  
  bool get isReady => _isReady;
  
  
  void runNow(VoidCallback action) {
    cancel();
    action();
    _isReady = false;
    _timer = Timer(duration, () {
      _isReady = true;
    });
  }
}
