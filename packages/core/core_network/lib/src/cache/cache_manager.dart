import 'dart:async';
import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';


enum CachePolicy {
  
  refreshForced,

  
  cacheFirst,

  
  cacheIfNotExpired,

  
  cacheAndNetwork,
}


class CacheManager {
  static const int _maxEntries = 500; 
  static const int _maxSizeBytes = 10 * 1024 * 1024; 

  late Box<String> _cacheBox;
  late Box<int> _metadataBox;
  final LoggingService? _loggingService;

  bool _initialized = false;
  final Map<String, Completer<void>> _pendingRequests = {};

  CacheManager({LoggingService? loggingService})
      : _loggingService = loggingService;

  
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _log('Initializing CacheManager');
      final dir = await getApplicationDocumentsDirectory();
      Hive.init('${dir.path}/advanced_cache');

      _cacheBox = await Hive.openBox<String>('network_cache_data');
      _metadataBox = await Hive.openBox<int>('network_cache_metadata');

      
      await _performCacheMaintenance();

      _initialized = true;
      _log('CacheManager successfully initialized');
    } catch (e) {
      _log('Error initializing CacheManager: $e', level: LogLevel.error);
    }
  }

  
  Future<void> set({
    required String key,
    required dynamic data,
    Duration expiration = const Duration(hours: 1),
  }) async {
    await _ensureInitialized();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final expirationTime = timestamp + expiration.inMilliseconds;

    final entry = {
      'data': data,
      'timestamp': timestamp,
      'expiration': expirationTime,
    };

    final String serialized = jsonEncode(entry);
    final int sizeBytes = serialized.length;

    await _cacheBox.put(key, serialized);
    await _metadataBox.put('${key}_size', sizeBytes);
    await _metadataBox.put('${key}_timestamp', timestamp);

    _log('Cache stored: $key (${_formatSize(sizeBytes)})');

    
    if (await _getCacheSize() > _maxSizeBytes ||
        await _getCacheCount() > _maxEntries) {
      unawaited(_performCacheMaintenance());
    }
  }

  
  Future<Map<String, dynamic>?> get(String key,
      {CachePolicy policy = CachePolicy.cacheIfNotExpired}) async {
    await _ensureInitialized();

    
    if (policy == CachePolicy.refreshForced) {
      return null;
    }

    
    final cachedData = _cacheBox.get(key);
    if (cachedData == null) {
      return null;
    }

    try {
      final entry = jsonDecode(cachedData) as Map<String, dynamic>;
      final expiration = entry['expiration'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      
      if (policy != CachePolicy.cacheFirst && now > expiration) {
        _log('Cache expired: $key');
        return null;
      }

      _log('Cache found: $key');
      return entry;
    } catch (e) {
      _log('Error reading cache: $e', level: LogLevel.error);
      return null;
    }
  }

  
  Future<void> remove(String key) async {
    await _ensureInitialized();

    await _cacheBox.delete(key);
    await _metadataBox.delete('${key}_size');
    await _metadataBox.delete('${key}_timestamp');

    _log('Cache removed: $key');
  }

  
  Future<void> clear() async {
    await _ensureInitialized();

    await _cacheBox.clear();
    await _metadataBox.clear();

    _log('Cache completely cleared');
  }

  
  Future<void> waitForRequest(String key) async {
    if (_pendingRequests.containsKey(key)) {
      await _pendingRequests[key]!.future;
    }
  }

  
  Completer<void> registerRequest(String key) {
    final completer = Completer<void>();
    _pendingRequests[key] = completer;
    return completer;
  }

  
  void completeRequest(String key) {
    if (_pendingRequests.containsKey(key)) {
      _pendingRequests[key]!.complete();
      _pendingRequests.remove(key);
    }
  }

  
  Future<int> _getCacheSize() async {
    int totalSize = 0;
    final keys = _metadataBox.keys.where((k) => k.toString().endsWith('_size'));

    for (final key in keys) {
      totalSize += _metadataBox.get(key) ?? 0;
    }

    return totalSize;
  }

  
  Future<int> _getCacheCount() async {
    return _cacheBox.length;
  }

  
  Future<void> _performCacheMaintenance() async {
    _log('Starting cache maintenance');

    
    final entries = <String, int>{};
    final sizeKeys =
        _metadataBox.keys.where((k) => k.toString().endsWith('_timestamp'));

    for (final key in sizeKeys) {
      final baseKey = key.toString().replaceAll('_timestamp', '');
      final timestamp = _metadataBox.get(key) ?? 0;
      entries[baseKey] = timestamp;
    }

    
    final sortedKeys = entries.keys.toList()
      ..sort((a, b) => entries[a]!.compareTo(entries[b]!));

    
    int currentSize = await _getCacheSize();
    int currentCount = await _getCacheCount();

    _log(
        'Current cache state: ${_formatSize(currentSize)}, $currentCount entries');

    for (final key in sortedKeys) {
      if (currentSize <= _maxSizeBytes * 0.8 &&
          currentCount <= _maxEntries * 0.8) {
        break;
      }

      final size = _metadataBox.get('${key}_size') ?? 0;
      await remove(key);

      currentSize -= size;
      currentCount--;
    }

    _log(
        'Maintenance completed: ${_formatSize(await _getCacheSize())}, ${await _getCacheCount()} entries');
  }

  
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  
  void _log(String message, {LogLevel level = LogLevel.debug}) {
    switch (level) {
      case LogLevel.debug:
        _loggingService?.debug(message, tag: 'CacheManager');
        break;
      case LogLevel.info:
        _loggingService?.info(message, tag: 'CacheManager');
        break;
      case LogLevel.warning:
        _loggingService?.warning(message, tag: 'CacheManager');
        break;
      case LogLevel.error:
        _loggingService?.error(message, tag: 'CacheManager');
        break;
      case LogLevel.fatal:
        _loggingService?.error('FATAL: $message', tag: 'CacheManager');
        break;
      case LogLevel.none:
        
        break;
    }
  }

  
  Future<void> dispose() async {
    if (_initialized) {
      await _cacheBox.close();
      await _metadataBox.close();
      _initialized = false;
    }
  }
}
