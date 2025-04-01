import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';


abstract class CacheService {
  
  Future<void> initialize();
  
  
  Future<T?> get<T>(String key);
  
  
  Future<void> set<T>(String key, T value, {Duration? expiration});
  
  
  Future<void> remove(String key);
  
  
  Future<void> clear();
  
  
  Future<bool> containsKey(String key);
  
  
  Future<bool> isExpired(String key);
  
  
  Future<void> dispose();
}


class CacheServiceImpl implements CacheService {
  late Box<String> _cache;
  late Box<String> _expirations;
  bool _initialized = false;
  
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    final dir = await getApplicationDocumentsDirectory();
    Hive.init('${dir.path}/cache');
    
    _cache = await Hive.openBox<String>('cache');
    _expirations = await Hive.openBox<String>('cache_expirations');
    
    _initialized = true;
  }
  
  @override
  Future<T?> get<T>(String key) async {
    _ensureInitialized();
    
    
    if (!await containsKey(key)) {
      return null;
    }
    
    
    if (await isExpired(key)) {
      await remove(key);
      return null;
    }
    
    
    final value = _cache.get(key);
    if (value == null) {
      return null;
    }
    
    try {
      final decoded = jsonDecode(value);
      return decoded as T?;
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> set<T>(String key, T value, {Duration? expiration}) async {
    _ensureInitialized();
    
    
    final encoded = jsonEncode(value);
    await _cache.put(key, encoded);
    
    
    if (expiration != null) {
      final expirationTime = DateTime.now().add(expiration).millisecondsSinceEpoch;
      await _expirations.put(key, expirationTime.toString());
    } else {
      await _expirations.delete(key);
    }
  }
  
  @override
  Future<void> remove(String key) async {
    _ensureInitialized();
    
    await _cache.delete(key);
    await _expirations.delete(key);
  }
  
  @override
  Future<void> clear() async {
    _ensureInitialized();
    
    await _cache.clear();
    await _expirations.clear();
  }
  
  @override
  Future<bool> containsKey(String key) async {
    _ensureInitialized();
    
    return _cache.containsKey(key);
  }
  
  @override
  Future<bool> isExpired(String key) async {
    _ensureInitialized();
    
    
    if (!_expirations.containsKey(key)) {
      return false;
    }
    
    
    final expirationString = _expirations.get(key);
    if (expirationString == null) {
      return false;
    }
    
    try {
      final expirationTime = int.parse(expirationString);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      return now > expirationTime;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _cache.close();
      await _expirations.close();
    }
  }
  
  
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('CacheService não foi inicializado. Chame initialize() primeiro.');
    }
  }
}
