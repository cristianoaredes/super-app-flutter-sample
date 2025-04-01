import 'package:core_interfaces/core_interfaces.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../interceptors/mock_interceptor.dart';
import 'web_api_client.dart';

class NetworkServiceImpl implements NetworkService {
  @override
  ApiClient createClient({required String baseUrl, AuthService? authService}) {
    if (kIsWeb) {
      if (kDebugMode) {
        print('🌐 Criando WebApiClient para ambiente web');
      }
      return WebApiClient(baseUrl: baseUrl);
    } else {
      return ApiClientImpl(baseUrl: baseUrl);
    }
  }

  @override
  Future<bool> get hasInternetConnection async {
    try {
      final response = await http.get(Uri.parse('https://google.com'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ApiClientImpl implements ApiClient {
  final String baseUrl;
  final Dio _dio = Dio();

  ApiClientImpl({required this.baseUrl}) {
    if (kDebugMode) {
      _dio.interceptors.add(MockInterceptor());

      _dio.options.baseUrl = '';
    } else {
      _dio.options.baseUrl = baseUrl;
    }
  }

  @override
  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? queryParams, Map<String, String>? headers}) async {
    bool isDashboardAccountSummary = path.contains('dashboard/account-summary');
    bool isDashboardTransactionSummary =
        path.contains('dashboard/transaction-summary');
    bool isDashboardQuickActions = path.contains('dashboard/quick-actions');

    if (kIsWeb &&
        (isDashboardAccountSummary ||
            isDashboardTransactionSummary ||
            isDashboardQuickActions)) {
      if (kDebugMode) {
        print('🌐 Usando dados mock para: $path');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      dynamic mockData;

      if (isDashboardAccountSummary) {
        mockData = {
          'balance': 12345.67,
          'accountNumber': '12345-6',
          'agency': '0001',
          'name': 'Conta Corrente',
          'status': 'active',
        };
      } else if (isDashboardTransactionSummary) {
        mockData = {
          'income': 5000.0,
          'expense': 3500.0,
          'balance': 1500.0,
          'period': 'Maio 2023',
          'transactions': [
            {
              'id': 'tx001',
              'description': 'Salário',
              'amount': 5000.0,
              'date': '2023-05-05',
              'type': 'income',
              'category': 'salary',
            },
            {
              'id': 'tx002',
              'description': 'Aluguel',
              'amount': -1500.0,
              'date': '2023-05-10',
              'type': 'expense',
              'category': 'housing',
            },
            {
              'id': 'tx003',
              'description': 'Supermercado',
              'amount': -800.0,
              'date': '2023-05-15',
              'type': 'expense',
              'category': 'food',
            },
          ],
        };
      } else if (isDashboardQuickActions) {
        mockData = [
          {
            'id': 'qa001',
            'title': 'Pix',
            'icon': 'pix',
            'route': '/pix',
          },
          {
            'id': 'qa002',
            'title': 'Transferência',
            'icon': 'transfer',
            'route': '/transfer',
          },
          {
            'id': 'qa003',
            'title': 'Pagamentos',
            'icon': 'payment',
            'route': '/payments',
          },
          {
            'id': 'qa004',
            'title': 'Cartões',
            'icon': 'card',
            'route': '/cards',
          },
        ];
      }

      return ApiResponse(
        statusCode: 200,
        data: mockData,
        headers: const {},
      );
    }

    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) {
          responseHeaders[name] = values.first;
        }
      });

      return ApiResponse(
        statusCode: response.statusCode ?? 200,
        data: response.data,
        headers: responseHeaders,
      );
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Error: $path - ${e.toString()}');
      }

      return ApiResponse(
        statusCode: 500,
        data: {'error': e.toString()},
        headers: const {},
      );
    }
  }

  @override
  Future<ApiResponse> post(String path,
      {dynamic body, Map<String, String>? headers}) async {
    try {
      final finalHeaders = {
        'Content-Type': 'application/json',
        ...?headers,
      };

      final response = await _dio.post(
        path,
        data: body,
        options: Options(headers: finalHeaders),
      );

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) {
          responseHeaders[name] = values.first;
        }
      });

      return ApiResponse(
        statusCode: response.statusCode ?? 200,
        data: response.data,
        headers: responseHeaders,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: {'error': e.toString()},
        headers: const {},
      );
    }
  }

  @override
  Future<ApiResponse> put(String path,
      {dynamic body, Map<String, String>? headers}) async {
    try {
      final finalHeaders = {
        'Content-Type': 'application/json',
        ...?headers,
      };

      final response = await _dio.put(
        path,
        data: body,
        options: Options(headers: finalHeaders),
      );

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) {
          responseHeaders[name] = values.first;
        }
      });

      return ApiResponse(
        statusCode: response.statusCode ?? 200,
        data: response.data,
        headers: responseHeaders,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: {'error': e.toString()},
        headers: const {},
      );
    }
  }

  @override
  Future<ApiResponse> delete(String path,
      {Map<String, String>? headers}) async {
    try {
      final response = await _dio.delete(
        path,
        options: Options(headers: headers),
      );

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) {
          responseHeaders[name] = values.first;
        }
      });

      return ApiResponse(
        statusCode: response.statusCode ?? 200,
        data: response.data,
        headers: responseHeaders,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: {'error': e.toString()},
        headers: const {},
      );
    }
  }
}
