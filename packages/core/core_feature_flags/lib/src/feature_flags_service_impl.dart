import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';


class FeatureFlagsServiceImpl implements FeatureFlagService {
  final Map<String, dynamic> _featureFlags = {};
  final Map<String, dynamic> _defaultFeatureFlags = {};
  final Map<String, List<FeatureFlagListener>> _listeners = {};

  
  FeatureFlagsServiceImpl({Map<String, dynamic>? defaultFlags}) {
    if (defaultFlags != null) {
      _defaultFeatureFlags.addAll(defaultFlags);
      _featureFlags.addAll(defaultFlags);
    }

    
    _addDefaultFlags();
  }

  void _addDefaultFlags() {
    
    final defaultFlags = <String, dynamic>{
      'enable_dark_mode': true,
      'enable_biometrics': true,
      'enable_push_notifications': true,
      'enable_analytics': !kDebugMode,
      'enable_crash_reporting': !kDebugMode,
      'enable_new_dashboard': false,
      'enable_card_management': true,
      'enable_pix_transfers': true,
      'enable_bill_payments': true,
      'enable_investments': false,
      'enable_loans': false,
      'enable_insurance': false,
      'enable_chat_support': true,
    };

    
    for (final entry in defaultFlags.entries) {
      if (!_defaultFeatureFlags.containsKey(entry.key)) {
        _defaultFeatureFlags[entry.key] = entry.value;

        
        if (!_featureFlags.containsKey(entry.key)) {
          _featureFlags[entry.key] = entry.value;
        }
      }
    }
  }

  @override
  Future<bool> isEnabled(String featureKey,
      {Map<String, dynamic>? attributes}) async {
    return _featureFlags[featureKey] == true;
  }

  @override
  Future<T?> getValue<T>(String featureKey,
      {T? defaultValue, Map<String, dynamic>? attributes}) async {
    final value = _featureFlags[featureKey];
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  @override
  void registerListener(String featureKey, FeatureFlagListener listener) {
    if (!_listeners.containsKey(featureKey)) {
      _listeners[featureKey] = [];
    }

    if (!_listeners[featureKey]!.contains(listener)) {
      _listeners[featureKey]!.add(listener);
    }
  }

  @override
  void removeListener(String featureKey, FeatureFlagListener listener) {
    if (_listeners.containsKey(featureKey)) {
      _listeners[featureKey]!.remove(listener);

      if (_listeners[featureKey]!.isEmpty) {
        _listeners.remove(featureKey);
      }
    }
  }

  @override
  Future<void> synchronize() async {
    
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<Map<String, dynamic>> getAllFeatureFlags() async {
    return Map.unmodifiable(_featureFlags);
  }

  
  void setFeatureFlag(String featureKey, dynamic value) {
    final oldValue = _featureFlags[featureKey];
    _featureFlags[featureKey] = value;

    
    if (_listeners.containsKey(featureKey)) {
      for (final listener in _listeners[featureKey]!) {
        listener(featureKey, oldValue, value);
      }
    }
  }
}
