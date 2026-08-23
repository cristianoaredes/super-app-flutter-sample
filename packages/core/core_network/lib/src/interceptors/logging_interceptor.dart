import 'package:core_interfaces/core_interfaces.dart';
import 'package:dio/dio.dart';


class LoggingInterceptor extends Interceptor {
  final LoggingService? _loggingService;

  LoggingInterceptor({LoggingService? loggingService})
      : _loggingService = loggingService;

  static Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) {
    final redacted = <String, dynamic>{};
    headers.forEach((key, value) {
      if (key.toLowerCase() == 'authorization' ||
          key.toLowerCase() == 'cookie') {
        redacted[key] = '<redacted>';
      } else {
        redacted[key] = value;
      }
    });
    return redacted;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final method = options.method;
    final url = options.uri.toString();

    _loggingService?.debug(
      'Request: $method $url',
      data: {
        'headers': redactHeaders(Map<String, dynamic>.from(options.headers)),
      },
      tag: 'Network',
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final method = response.requestOptions.method;
    final url = response.requestOptions.uri.toString();
    final statusCode = response.statusCode;

    _loggingService?.debug(
      'Response: $method $url - Status: $statusCode',
      tag: 'Network',
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final method = err.requestOptions.method;
    final url = err.requestOptions.uri.toString();
    final statusCode = err.response?.statusCode;
    final errorMessage = err.message;

    _loggingService?.error(
      'Error: $method $url - Status: $statusCode - $errorMessage',
      error: err,
      stackTrace: err.stackTrace,
      tag: 'Network',
    );

    handler.next(err);
  }
}
