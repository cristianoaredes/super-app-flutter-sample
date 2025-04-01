import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';


class MockInterceptor extends Interceptor {
  final Map<String, dynamic> _mockResponses = {
    
    '/dashboard/account-summary': {
      'accountNumber': '12345-6',
      'accountType': 'Conta Corrente',
      'balance': 1250.75,
      'availableBalance': 1200.50,
      'currency': 'BRL',
      'owner': 'João Silva',
      'lastUpdate': '2023-06-15T10:30:00Z',
    },
    '/dashboard/transaction-summary': {
      'totalIncome': 3500.00,
      'totalExpenses': 2250.25,
      'balance': 1249.75,
      'period': 'Junho 2023',
      'transactions': [
        {
          'id': 'tx001',
          'description': 'Salário',
          'amount': 3500.00,
          'type': 'income',
          'category': 'Salário',
          'date': '2023-06-05T08:00:00Z',
        },
        {
          'id': 'tx002',
          'description': 'Aluguel',
          'amount': -1200.00,
          'type': 'expense',
          'category': 'Moradia',
          'date': '2023-06-10T10:00:00Z',
        },
        {
          'id': 'tx003',
          'description': 'Supermercado',
          'amount': -450.25,
          'type': 'expense',
          'category': 'Alimentação',
          'date': '2023-06-12T15:30:00Z',
        },
        {
          'id': 'tx004',
          'description': 'Internet',
          'amount': -120.00,
          'type': 'expense',
          'category': 'Serviços',
          'date': '2023-06-15T09:15:00Z',
        },
        {
          'id': 'tx005',
          'description': 'Transporte',
          'amount': -80.00,
          'type': 'expense',
          'category': 'Transporte',
          'date': '2023-06-14T18:20:00Z',
        },
      ],
    },
    '/dashboard/quick-actions': [
      {
        'id': 'qa001',
        'title': 'Pix',
        'description': 'Transferência instantânea',
        'icon': 'pix',
        'route': '/pix',
      },
      {
        'id': 'qa002',
        'title': 'Pagar',
        'description': 'Pagar contas e boletos',
        'icon': 'payment',
        'route': '/payments',
      },
      {
        'id': 'qa003',
        'title': 'Transferir',
        'description': 'Transferência entre contas',
        'icon': 'transfer',
        'route': '/transfer',
      },
      {
        'id': 'qa004',
        'title': 'Cartões',
        'description': 'Gerenciar cartões',
        'icon': 'card',
        'route': '/cards',
      },
    ],

    
    '/cards': [
      {
        'id': 'card001',
        'type': 'credit',
        'number': '**** **** **** 1234',
        'expiryDate': '12/25',
        'cardholderName': 'JOAO SILVA',
        'brand': 'visa',
        'status': 'active',
        'limit': 5000.00,
        'availableLimit': 3200.50,
        'dueDate': '2023-07-10',
        'closingDate': '2023-07-03',
        'currentInvoice': 1799.50,
      },
      {
        'id': 'card002',
        'type': 'debit',
        'number': '**** **** **** 5678',
        'expiryDate': '10/24',
        'cardholderName': 'JOAO SILVA',
        'brand': 'mastercard',
        'status': 'active',
      },
    ],
    '/cards/card001/statement': {
      'cardId': 'card001',
      'period': 'Junho 2023',
      'totalAmount': 1799.50,
      'dueDate': '2023-07-10',
      'closingDate': '2023-07-03',
      'transactions': [
        {
          'id': 'ctx001',
          'description': 'Restaurante Silva',
          'amount': 89.90,
          'date': '2023-06-02T20:15:00Z',
          'category': 'Alimentação',
          'installments': null,
        },
        {
          'id': 'ctx002',
          'description': 'Posto Ipiranga',
          'amount': 200.00,
          'date': '2023-06-05T10:30:00Z',
          'category': 'Transporte',
          'installments': null,
        },
        {
          'id': 'ctx003',
          'description': 'Magazine Luiza',
          'amount': 1200.00,
          'date': '2023-06-10T14:45:00Z',
          'category': 'Compras',
          'installments': {
            'current': 1,
            'total': 3,
            'amount': 400.00,
          },
        },
        {
          'id': 'ctx004',
          'description': 'Netflix',
          'amount': 39.90,
          'date': '2023-06-15T00:00:00Z',
          'category': 'Entretenimento',
          'installments': null,
        },
        {
          'id': 'ctx005',
          'description': 'Farmácia São Paulo',
          'amount': 69.70,
          'date': '2023-06-18T16:20:00Z',
          'category': 'Saúde',
          'installments': null,
        },
      ],
    },

    
    '/pix/keys': [
      {
        'id': 'pixkey001',
        'type': 'cpf',
        'value': '123.456.789-00',
        'createdAt': '2023-01-15T10:30:00Z',
        'status': 'active',
      },
      {
        'id': 'pixkey002',
        'type': 'email',
        'value': 'joao.silva@email.com',
        'createdAt': '2023-02-20T14:45:00Z',
        'status': 'active',
      },
      {
        'id': 'pixkey003',
        'type': 'phone',
        'value': '+5511987654321',
        'createdAt': '2023-03-10T09:15:00Z',
        'status': 'active',
      },
    ],
    '/pix/transactions': [
      {
        'id': 'pix001',
        'type': 'sent',
        'amount': 150.00,
        'description': 'Pagamento almoço',
        'date': '2023-06-10T13:30:00Z',
        'status': 'completed',
        'sender': {
          'name': 'João Silva',
          'document': '123.456.789-00',
          'bank': 'Banco Digital',
          'agency': '0001',
          'account': '12345-6',
          'pixKey': {
            'id': 'pixkey001',
            'type': 'cpf',
            'value': '123.456.789-00',
          },
        },
        'receiver': {
          'name': 'Maria Souza',
          'document': '987.654.321-00',
          'bank': 'Banco XYZ',
          'agency': '4321',
          'account': '98765-4',
          'pixKey': {
            'id': 'pixkey004',
            'type': 'cpf',
            'value': '987.654.321-00',
          },
        },
      },
      {
        'id': 'pix002',
        'type': 'received',
        'amount': 75.50,
        'description': 'Reembolso',
        'date': '2023-06-12T16:45:00Z',
        'status': 'completed',
        'sender': {
          'name': 'Carlos Oliveira',
          'document': '111.222.333-44',
          'bank': 'Banco ABC',
          'agency': '1234',
          'account': '56789-0',
          'pixKey': {
            'id': 'pixkey005',
            'type': 'email',
            'value': 'carlos@email.com',
          },
        },
        'receiver': {
          'name': 'João Silva',
          'document': '123.456.789-00',
          'bank': 'Banco Digital',
          'agency': '0001',
          'account': '12345-6',
          'pixKey': {
            'id': 'pixkey002',
            'type': 'email',
            'value': 'joao.silva@email.com',
          },
        },
      },
    ],

    
    '/payments': [
      {
        'id': 'payment001',
        'barcode': '34191790010104351004791020150008291070026000',
        'amount': 120.45,
        'dueDate': '2023-06-20',
        'paymentDate': '2023-06-18',
        'status': 'paid',
        'recipient': 'Empresa de Energia XYZ',
        'description': 'Conta de Energia',
      },
      {
        'id': 'payment002',
        'barcode': '34191790010104351004791020150008291070026001',
        'amount': 89.90,
        'dueDate': '2023-06-25',
        'paymentDate': null,
        'status': 'pending',
        'recipient': 'Empresa de Água ABC',
        'description': 'Conta de Água',
      },
      {
        'id': 'payment003',
        'barcode': '34191790010104351004791020150008291070026002',
        'amount': 59.99,
        'dueDate': '2023-06-15',
        'paymentDate': '2023-06-14',
        'status': 'paid',
        'recipient': 'Internet Fibra Ltda',
        'description': 'Internet Fibra',
      },
    ],
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('🌐 Request: ${options.method} ${options.path}');
      print('Headers: ${options.headers}');
      if (options.data != null) {
        print('Data: ${options.data}');
      }
    }

    
    String path = options.path;

    
    bool isDashboardAccountSummary = path.contains('dashboard/account-summary');
    bool isDashboardTransactionSummary =
        path.contains('dashboard/transaction-summary');
    bool isDashboardQuickActions = path.contains('dashboard/quick-actions');

    if (isDashboardAccountSummary ||
        isDashboardTransactionSummary ||
        isDashboardQuickActions) {
      if (kDebugMode) {
        print('🌐 Interceptando rota: $path');
      }

      
      Future.delayed(const Duration(milliseconds: 300), () {
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

        final response = Response(
          requestOptions: options,
          data: mockData,
          statusCode: 200,
        );
        handler.resolve(response);
      });
      return;
    }

    
    
    if (kDebugMode) {
      print('🌐 Paths disponíveis: ${_mockResponses.keys.join(', ')}');
      print('🌐 Path solicitado: $path');
    }

    
    String? matchingPath;
    for (final key in _mockResponses.keys) {
      if (path.contains(key)) {
        matchingPath = key;
        break;
      }
    }

    if (matchingPath != null) {
      if (kDebugMode) {
        print('🌐 Mock response for $matchingPath');
      }

      
      Future.delayed(const Duration(milliseconds: 300), () {
        final mockData = _mockResponses[matchingPath];
        final response = Response(
          requestOptions: options,
          data: mockData,
          statusCode: 200,
        );
        handler.resolve(response);
      });
      return;
    }

    
    if (kDebugMode) {
      print('🌐 No mock found for $path');
    }

    
    Future.delayed(const Duration(milliseconds: 300), () {
      final mockData = {
        'message': 'Mock data not found for $path',
        'status': 'error',
      };
      final response = Response(
        requestOptions: options,
        data: mockData,
        statusCode: 404,
      );
      handler.resolve(response);
    });
  }
}
