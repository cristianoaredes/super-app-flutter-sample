import 'auth_service.dart';


abstract class NetworkService {
  
  ApiClient createClient({required String baseUrl, AuthService? authService});

  
  Future<bool> get hasInternetConnection;
}


abstract class ApiClient {
  
  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? queryParams, Map<String, String>? headers});

  
  Future<ApiResponse> post(String path,
      {dynamic body, Map<String, String>? headers});

  
  Future<ApiResponse> put(String path,
      {dynamic body, Map<String, String>? headers});

  
  Future<ApiResponse> delete(String path, {Map<String, String>? headers});
}


class ApiResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;

  ApiResponse({
    required this.statusCode,
    required this.data,
    required this.headers,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
