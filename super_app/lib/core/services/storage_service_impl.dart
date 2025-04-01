import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:shared_preferences/shared_preferences.dart';

class StorageServiceImpl implements StorageService {
  late SharedPreferences _prefs;
  final SecureStorageService _secureStorage = _MockSecureStorageService();
  final Map<String, dynamic> _memoryStorage = {};
  bool _initialized = false;

  StorageServiceImpl();

  
  @override
  Future<void> initialize([CoreLibraryDependencies? dependencies]) async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao inicializar SharedPreferences: $e');
        print('Usando armazenamento em memória como fallback');
      }
      
      _initialized = true;
    }
  }

  @override
  Future<bool> setValue<T>(String key, T value) async {
    if (!_initialized) {
      throw StateError(
          'StorageService não foi inicializado. Chame initialize() primeiro.');
    }

    try {
      if (value is String) {
        return _prefs.setString(key, value);
      } else if (value is int) {
        return _prefs.setInt(key, value);
      } else if (value is double) {
        return _prefs.setDouble(key, value);
      } else if (value is bool) {
        return _prefs.setBool(key, value);
      } else if (value is List<String>) {
        return _prefs.setStringList(key, value);
      } else {
        
        final jsonString = jsonEncode(value);
        return _prefs.setString(key, jsonString);
      }
    } catch (e) {
      
      _memoryStorage[key] = value;
      return true;
    }
  }

  @override
  Future<T?> getValue<T>(String key) async {
    if (!_initialized) {
      throw StateError(
          'StorageService não foi inicializado. Chame initialize() primeiro.');
    }

    
    if (_memoryStorage.containsKey(key)) {
      final memValue = _memoryStorage[key];
      if (memValue is T) {
        return memValue;
      }
    }

    try {
      if (!_prefs.containsKey(key)) {
        return null;
      }

      final value = _prefs.get(key);

      if (value is T) {
        return value;
      }

      if (T == String) {
        return _prefs.getString(key) as T?;
      } else if (T == int) {
        return _prefs.getInt(key) as T?;
      } else if (T == double) {
        return _prefs.getDouble(key) as T?;
      } else if (T == bool) {
        return _prefs.getBool(key) as T?;
      } else if (T == List<String>) {
        return _prefs.getStringList(key) as T?;
      } else {
        
        final jsonString = _prefs.getString(key);
        if (jsonString == null) {
          return null;
        }

        try {
          final jsonValue = jsonDecode(jsonString);
          return jsonValue as T?;
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      
      if (kDebugMode) {
        print('Erro ao acessar SharedPreferences: $e');
      }
      return null;
    }
  }

  @override
  Future<bool> removeValue(String key) async {
    if (!_initialized) {
      throw StateError(
          'StorageService não foi inicializado. Chame initialize() primeiro.');
    }

    try {
      return _prefs.remove(key);
    } catch (e) {
      
      _memoryStorage.remove(key);
      return true;
    }
  }

  @override
  Future<bool> clear() async {
    if (!_initialized) {
      throw StateError(
          'StorageService não foi inicializado. Chame initialize() primeiro.');
    }

    try {
      return _prefs.clear();
    } catch (e) {
      
      _memoryStorage.clear();
      return true;
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    if (!_initialized) {
      throw StateError(
          'StorageService não foi inicializado. Chame initialize() primeiro.');
    }

    
    if (_memoryStorage.containsKey(key)) {
      return true;
    }

    try {
      return _prefs.containsKey(key);
    } catch (e) {
      
      return false;
    }
  }

  @override
  Future<String> getApplicationDocumentsDirectory() async {
    if (kIsWeb) {
      return '';
    }

    try {
      final directory = await path_provider.getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      
      return '';
    }
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
      final map = jsonDecode(value) as Map<String, dynamic>;
      return fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setSecureObject<T>(String key, T value) async {
    final jsonString = jsonEncode(value);
    await setSecureValue(key, jsonString);
  }
}
