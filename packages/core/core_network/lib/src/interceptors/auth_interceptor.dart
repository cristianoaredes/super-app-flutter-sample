import 'package:core_interfaces/core_interfaces.dart';
import 'package:dio/dio.dart';


class AuthInterceptor extends Interceptor {
  final AuthService _authService;
  final Dio _dio;

  AuthInterceptor({required AuthService authService, required Dio dio})
      : _authService = authService,
        _dio = dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_authService.isAuthenticated) {
      final token = await _authService.accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    
    if (err.response?.statusCode == 401 && _authService.isAuthenticated) {
      try {
        final success = await _authService.refreshToken();
        if (success) {
          
          final newToken = await _authService.accessToken;
          if (newToken != null) {
            
            final options = err.requestOptions;
            options.headers['Authorization'] = 'Bearer $newToken';

            
            final response = await _dio.fetch(options);
            return handler.resolve(response);
          }
        }
      } catch (e) {
        
      }
    }

    handler.next(err);
  }
}
