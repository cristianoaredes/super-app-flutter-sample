import 'package:core_interfaces/core_interfaces.dart';
import 'package:dio/dio.dart';


class ApiClientImpl implements ApiClient {
  final Dio _dio;

  ApiClientImpl({required Dio dio}) : _dio = dio;

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      return _createApiResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: {'error': e.toString()},
        headers: const {},
      );
    }
  }

  @override
  Future<ApiResponse> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: body,
        options: Options(headers: headers),
      );

      return _createApiResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: {'error': e.toString()},
        headers: const {},
      );
    }
  }

  @override
  Future<ApiResponse> put(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: body,
        options: Options(headers: headers),
      );

      return _createApiResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: {'error': e.toString()},
        headers: const {},
      );
    }
  }

  @override
  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        options: Options(headers: headers),
      );

      return _createApiResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: {'error': e.toString()},
        headers: const {},
      );
    }
  }

  
  ApiResponse _createApiResponse(Response response) {
    final headersMap = <String, String>{};
    response.headers.forEach((name, values) {
      if (values.isNotEmpty) {
        headersMap[name] = values.join(', ');
      }
    });

    return ApiResponse(
      statusCode: response.statusCode ?? 500,
      data: response.data,
      headers: headersMap,
    );
  }

  
  ApiResponse _handleDioError(DioException error) {
    final statusCode = error.response?.statusCode ?? 500;
    final headers = <String, String>{};

    error.response?.headers.forEach((name, values) {
      if (values.isNotEmpty) {
        headers[name] = values.join(', ');
      }
    });

    final errorData = error.response?.data ?? {'error': error.message};

    return ApiResponse(
      statusCode: statusCode,
      data: errorData,
      headers: headers,
    );
  }
}
