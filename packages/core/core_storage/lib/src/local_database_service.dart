import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';


abstract class LocalDatabaseService {
  
  Future<void> initialize();
  
  
  Future<Box<dynamic>> openBox(String name);
  
  
  bool isBoxOpen(String name);
  
  
  Future<void> closeBox(String name);
  
  
  Future<void> setValue<T>(String boxName, String key, T value);
  
  
  Future<T?> getValue<T>(String boxName, String key);
  
  
  Future<void> removeValue(String boxName, String key);
  
  
  Future<void> clearBox(String boxName);
  
  
  Future<bool> containsKey(String boxName, String key);
  
  
  Future<Map<String, dynamic>> getAllValues(String boxName);
  
  
  Future<void> dispose();
}


class HiveLocalDatabaseService implements LocalDatabaseService {
  final Map<String, Box<dynamic>> _boxes = {};
  bool _initialized = false;
  
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter('${dir.path}/hive');
    
    _initialized = true;
  }
  
  @override
  Future<Box<dynamic>> openBox(String name) async {
    _ensureInitialized();
    
    if (_boxes.containsKey(name)) {
      return _boxes[name]!;
    }
    
    final box = await Hive.openBox(name);
    _boxes[name] = box;
    return box;
  }
  
  @override
  bool isBoxOpen(String name) {
    return _boxes.containsKey(name) && _boxes[name]!.isOpen;
  }
  
  @override
  Future<void> closeBox(String name) async {
    if (isBoxOpen(name)) {
      await _boxes[name]!.close();
      _boxes.remove(name);
    }
  }
  
  @override
  Future<void> setValue<T>(String boxName, String key, T value) async {
    final box = await _getBox(boxName);
    
    if (value is int || value is double || value is bool || value is String || value is List) {
      await box.put(key, value);
    } else {
      
      final jsonString = jsonEncode(value);
      await box.put(key, jsonString);
    }
  }
  
  @override
  Future<T?> getValue<T>(String boxName, String key) async {
    final box = await _getBox(boxName);
    
    if (!box.containsKey(key)) {
      return null;
    }
    
    final value = box.get(key);
    
    if (value is T) {
      return value;
    }
    
    if (value is String && T != String) {
      try {
        final jsonValue = jsonDecode(value);
        return jsonValue as T?;
      } catch (_) {
        return null;
      }
    }
    
    return null;
  }
  
  @override
  Future<void> removeValue(String boxName, String key) async {
    final box = await _getBox(boxName);
    await box.delete(key);
  }
  
  @override
  Future<void> clearBox(String boxName) async {
    final box = await _getBox(boxName);
    await box.clear();
  }
  
  @override
  Future<bool> containsKey(String boxName, String key) async {
    final box = await _getBox(boxName);
    return box.containsKey(key);
  }
  
  @override
  Future<Map<String, dynamic>> getAllValues(String boxName) async {
    final box = await _getBox(boxName);
    final result = <String, dynamic>{};
    
    for (final key in box.keys) {
      result[key.toString()] = box.get(key);
    }
    
    return result;
  }
  
  @override
  Future<void> dispose() async {
    for (final boxName in _boxes.keys) {
      await closeBox(boxName);
    }
  }
  
  
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('LocalDatabaseService não foi inicializado. Chame initialize() primeiro.');
    }
  }
  
  
  Future<Box<dynamic>> _getBox(String name) async {
    if (isBoxOpen(name)) {
      return _boxes[name]!;
    }
    
    return openBox(name);
  }
}
