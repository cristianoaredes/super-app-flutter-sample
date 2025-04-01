import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';


class WebStorageService implements StorageService {
  final Map<String, dynamic> _memoryStorage = {};
  final SecureStorageService _secureStorage = _MockSecureStorageService();
  bool _initialized = false;

  
  @override
  Future<void> initialize([CoreLibraryDependencies? dependencies]) async {
    if (_initialized) return;
    
    if (kDebugMode) {
      print('Inicializando WebStorageService');
    }
    
    _initialized = true;
  }

  @override
  Future<bool> setValue<T>(String key, T value) async {
    if (!_initialized) {
      throw StateError('StorageService não foi inicializado. Chame initialize() primeiro.');
    }
    
    _memoryStorage[key] = value;
    return true;
  }

  @override
  Future<T?> getValue<T>(String key) async {
    if (!_initialized) {
      throw StateError('StorageService não foi inicializado. Chame initialize() primeiro.');
    }
    
    if (!_memoryStorage.containsKey(key)) {
      return null;
    }
    
    final value = _memoryStorage[key];
    
    if (value is T) {
      return value;
    }
    
    return null;
  }

  @override
  Future<bool> removeValue(String key) async {
    if (!_initialized) {
      throw StateError('StorageService não foi inicializado. Chame initialize() primeiro.');
    }
    
    _memoryStorage.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    if (!_initialized) {
      throw StateError('StorageService não foi inicializado. Chame initialize() primeiro.');
    }
    
    _memoryStorage.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async {
    if (!_initialized) {
      throw StateError('StorageService não foi inicializado. Chame initialize() primeiro.');
    }
    
    return _memoryStorage.containsKey(key);
  }

  @override
  Future<String> getApplicationDocumentsDirectory() async {
    return '';
  }

  @override
  SecureStorageService get secureStorage => _secureStorage;
}


class _MockSecureStorageService implements SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<void> clearSecureStorage() async {
    _storage.clear();
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<String?> getSecureValue(String key) async {
    return _storage[key];
  }

  @override
  Future<void> removeSecureValue(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> setSecureValue(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<T?> getSecureObject<T>(
      String key, T Function(Map<String, dynamic>) fromJson) async {
    final value = await getSecureValue(key);
    if (value == null) return null;

    try {
      final jsonValue = jsonDecode(value);
      if (jsonValue is Map<String, dynamic>) {
        return fromJson(jsonValue);
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> setSecureObject<T>(String key, T value) async {
    final jsonString = jsonEncode(value);
    await setSecureValue(key, jsonString);
  }
}
