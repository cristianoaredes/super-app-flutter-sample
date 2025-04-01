import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';


abstract class ConnectivityService {
  
  Future<bool> get hasInternetConnection;

  
  Stream<bool> get connectivityChanges;

  
  Future<void> initialize();

  
  Future<void> dispose();
}


class ConnectivityServiceImpl implements ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isInitialized = false;

  @override
  Stream<bool> get connectivityChanges => _connectivityController.stream;

  @override
  Future<bool> get hasInternetConnection async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    
    final initialResult = await _connectivity.checkConnectivity();
    _connectivityController.add(initialResult != ConnectivityResult.none);

    
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _connectivityController.add(result != ConnectivityResult.none);
    });

    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _connectivityController.close();
  }
}
