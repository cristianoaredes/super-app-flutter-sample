import 'package:core_interfaces/core_interfaces.dart';
import 'package:dio/dio.dart';


class LoggingInterceptor extends Interceptor {
  final LoggingService? _loggingService;

  LoggingInterceptor({LoggingService? loggingService})
      : _loggingService = loggingService;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final method = options.method;
    final url = options.uri.toString();
    final headers = options.headers;
    final data = options.data;

    _loggingService?.debug(
      'Request: $method $url',
      data: {
        'headers': headers,
        'data': data,
      },
      tag: 'Network',
    );

    
    if (_loggingService == null) {
      print('🌐 Request: $method $url');
      print('Headers: $headers');
      if (data != null) {
        print('Data: $data');
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final method = response.requestOptions.method;
    final url = response.requestOptions.uri.toString();
    final statusCode = response.statusCode;
    final headers = response.headers.map;
    final data = response.data;

    _loggingService?.debug(
      'Response: $method $url - Status: $statusCode',
      data: {
        'headers': headers,
        'data': data,
      },
      tag: 'Network',
    );

    
    if (_loggingService == null) {
      print('🌐 Response: $method $url - Status: $statusCode');
      print('Headers: $headers');
      print('Data: $data');
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final method = err.requestOptions.method;
    final url = err.requestOptions.uri.toString();
    final statusCode = err.response?.statusCode;
    final errorMessage = err.message;
    final errorData = err.response?.data;

    _loggingService?.error(
      'Error: $method $url - Status: $statusCode - $errorMessage',
      error: err,
      stackTrace: err.stackTrace,
      data: {
        'data': errorData,
      },
      tag: 'Network',
    );

    
    if (_loggingService == null) {
      print('🌐 Error: $method $url - Status: $statusCode - $errorMessage');
      print('Error Data: $errorData');
      print('StackTrace: ${err.stackTrace}');
    }

    handler.next(err);
  }
}
