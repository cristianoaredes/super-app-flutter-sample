import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';
import 'package:dio/dio.dart';

import '../cache/cache_manager.dart';


class CacheInterceptor extends Interceptor {
  final CacheManager _cacheManager;
  final Duration defaultDuration;

  CacheInterceptor({
    this.defaultDuration = const Duration(minutes: 30),
    LoggingService? loggingService,
  }) : _cacheManager = CacheManager(loggingService: loggingService);

  
  Future<void> initialize() async {
    await _cacheManager.initialize();
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    
    if (options.method != 'GET') {
      return handler.next(options);
    }

    
    final useCache = options.extra['use_cache'] == true;
    if (!useCache) {
      return handler.next(options);
    }

    
    final policy = options.extra['cache_policy'] != null
        ? CachePolicy.values[(options.extra['cache_policy'] as int)]
        : CachePolicy.cacheIfNotExpired;

    
    final cacheKey = _generateCacheKey(options);

    
    if (policy == CachePolicy.cacheAndNetwork) {
      
      final cacheEntry =
          await _cacheManager.get(cacheKey, policy: CachePolicy.cacheFirst);

      if (cacheEntry != null) {
        final response = Response(
          data: cacheEntry['data'],
          statusCode: 200,
          requestOptions: options,
          headers: Headers.fromMap({
            'x-cache': ['HIT'],
            'x-cache-timestamp': [
              DateTime.fromMillisecondsSinceEpoch(
                      cacheEntry['timestamp'] as int)
                  .toIso8601String()
            ],
            'x-cache-policy': ['cache_and_network'],
          }),
        );

        
        handler.resolve(response);

        
        _cacheManager.registerRequest(cacheKey);

        try {
          
          final freshOptions = options.copyWith(
            extra: Map.from(options.extra)..remove('use_cache'),
          );

          
          handler.next(freshOptions);
        } finally {
          
          _cacheManager.completeRequest(cacheKey);
        }

        return;
      }

      
      await _cacheManager.waitForRequest(cacheKey);
      return handler.next(options);
    }

    
    final cacheEntry = await _cacheManager.get(cacheKey, policy: policy);

    if (cacheEntry != null) {
      
      final response = Response(
        data: cacheEntry['data'],
        statusCode: 200,
        requestOptions: options,
        headers: Headers.fromMap({
          'x-cache': ['HIT'],
          'x-cache-timestamp': [
            DateTime.fromMillisecondsSinceEpoch(cacheEntry['timestamp'] as int)
                .toIso8601String()
          ],
        }),
      );

      return handler.resolve(response);
    }

    
    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    
    if (response.requestOptions.method != 'GET') {
      return handler.next(response);
    }

    
    final useCache = response.requestOptions.extra['use_cache'] == true;
    if (!useCache) {
      return handler.next(response);
    }

    
    if (response.statusCode != 200) {
      return handler.next(response);
    }

    
    final cacheDuration =
        response.requestOptions.extra['cache_duration'] != null
            ? Duration(
                milliseconds:
                    response.requestOptions.extra['cache_duration'] as int)
            : defaultDuration;

    
    final cacheKey = _generateCacheKey(response.requestOptions);

    
    _cacheManager.set(
      key: cacheKey,
      data: response.data,
      expiration: cacheDuration,
    );

    
    response.headers.add('x-cache', 'MISS');

    handler.next(response);
  }

  
  String _generateCacheKey(RequestOptions options) {
    final buffer = StringBuffer();
    buffer.write(options.method);
    buffer.write('|');
    buffer.write(options.uri.toString());

    
    if (options.queryParameters.isNotEmpty) {
      final sortedParams = Map.fromEntries(
          options.queryParameters.entries.toList()
            ..sort((e1, e2) => e1.key.compareTo(e2.key)));
      buffer.write('|');
      buffer.write(jsonEncode(sortedParams));
    }

    
    if (options.data != null) {
      buffer.write('|');
      buffer.write(jsonEncode(options.data));
    }

    return buffer.toString();
  }

  
  Future<void> clearCache() async {
    await _cacheManager.clear();
  }

  
  Future<void> dispose() async {
    await _cacheManager.dispose();
  }

  
  Future<void> close() async {
    await dispose();
  }
}
