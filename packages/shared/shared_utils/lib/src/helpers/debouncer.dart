import 'dart:async';

import 'package:flutter/foundation.dart';


class Debouncer {
  final Duration delay;
  Timer? _timer;
  
  Debouncer({this.delay = const Duration(milliseconds: 300)});
  
  
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }
  
  
  void runWithParams<T>(void Function(T) action, T param) {
    _timer?.cancel();
    _timer = Timer(delay, () => action(param));
  }
  
  
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
  
  
  bool get isActive => _timer?.isActive ?? false;
  
  
  void runNow(VoidCallback action) {
    cancel();
    action();
  }
}
