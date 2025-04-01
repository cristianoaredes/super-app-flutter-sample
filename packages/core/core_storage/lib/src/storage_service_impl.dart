import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_storage_service.dart';
import 'local_database_service.dart';
import 'file_storage_service.dart';
import 'cache_service.dart';


class StorageServiceImpl implements StorageService, CoreLibrary {
  late SharedPreferences _prefs;
  late SecureStorageService _secureStorage;
  late LocalDatabaseService _localDatabase;
  late FileStorageService _fileStorage;
  late CacheService _cacheService;

  bool _initialized = false;

  @override
  String get id => 'core_storage';

  @override
  Future<void> initialize([CoreLibraryDependencies? dependencies]) async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _secureStorage = SecureStorageServiceImpl();
    _localDatabase = HiveLocalDatabaseService();
    _fileStorage = FileStorageServiceImpl();
    _cacheService = CacheServiceImpl();

    await _localDatabase.initialize();
    await _fileStorage.initialize();
    await _cacheService.initialize();

    _initialized = true;

    if (dependencies != null) {
      final loggingService =
          dependencies.services[LoggingService] as LoggingService?;
      loggingService?.info('StorageService initialized', tag: 'StorageService');
    }
  }

  @override
  Future<bool> setValue<T>(String key, T value) async {
    _ensureInitialized();

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
  }

  @override
  Future<T?> getValue<T>(String key) async {
    _ensureInitialized();

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
  }

  @override
  Future<bool> removeValue(String key) async {
    _ensureInitialized();
    return _prefs.remove(key);
  }

  @override
  Future<bool> clear() async {
    _ensureInitialized();
    return _prefs.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    _ensureInitialized();
    return _prefs.containsKey(key);
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

  
  SecureStorageService get secureStorage {
    _ensureInitialized();
    return _secureStorage;
  }

  
  LocalDatabaseService get localDatabase {
    _ensureInitialized();
    return _localDatabase;
  }

  
  FileStorageService get fileStorage {
    _ensureInitialized();
    return _fileStorage;
  }

  
  CacheService get cacheService {
    _ensureInitialized();
    return _cacheService;
  }

  
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
          'StorageService was not initialized. Call initialize() first.');
    }
  }

  @override
  Map<Type, Object> get services => {
        StorageService: this,
        SecureStorageService: _secureStorage,
        LocalDatabaseService: _localDatabase,
        FileStorageService: _fileStorage,
        CacheService: _cacheService,
      };

  @override
  List<BlocProvider> get globalBlocs => [];

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _localDatabase.dispose();
      await _cacheService.dispose();
    }
  }
}
