import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';


class WebApiClient implements ApiClient {
  final String baseUrl;

  WebApiClient({required this.baseUrl});

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    
    bool isDashboardAccountSummary = path.contains('dashboard/account-summary');
    bool isDashboardTransactionSummary = path.contains('dashboard/transaction-summary');
    bool isDashboardQuickActions = path.contains('dashboard/quick-actions');
    
    if (kDebugMode) {
      print('🌐 WebApiClient.get: $path');
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
    } else {
      
      mockData = {
        'message': 'Dados mock para $path',
        'success': true,
      };
    }
    
    return ApiResponse(
      statusCode: 200,
      data: mockData,
      headers: const {},
    );
  }

  @override
  Future<ApiResponse> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    if (kDebugMode) {
      print('🌐 WebApiClient.post: $path');
      print('🌐 Body: $body');
    }
    
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    
    final mockData = {
      'message': 'Dados enviados com sucesso',
      'success': true,
      'data': body,
    };
    
    return ApiResponse(
      statusCode: 200,
      data: mockData,
      headers: const {},
    );
  }

  @override
  Future<ApiResponse> put(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    if (kDebugMode) {
      print('🌐 WebApiClient.put: $path');
      print('🌐 Body: $body');
    }
    
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    
    final mockData = {
      'message': 'Dados atualizados com sucesso',
      'success': true,
      'data': body,
    };
    
    return ApiResponse(
      statusCode: 200,
      data: mockData,
      headers: const {},
    );
  }

  @override
  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    if (kDebugMode) {
      print('🌐 WebApiClient.delete: $path');
    }
    
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    
    final mockData = {
      'message': 'Recurso excluído com sucesso',
      'success': true,
    };
    
    return ApiResponse(
      statusCode: 200,
      data: mockData,
      headers: const {},
    );
  }
}
