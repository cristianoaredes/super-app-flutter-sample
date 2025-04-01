import 'package:go_router/go_router.dart';

import '../presentation/pages/dashboard_page.dart';
import '../presentation/pages/account_details_page.dart';
import '../presentation/pages/transaction_details_page.dart';


class DashboardRoutes {
  static const String dashboardPath = '/dashboard';
  static const String accountDetailsPath = '/dashboard/account';
  static const String transactionDetailsPath = '/dashboard/transaction/:id';

  
  static List<GoRoute> get routes => [
        GoRoute(
          path: dashboardPath,
          name: 'dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: accountDetailsPath,
          name: 'account_details',
          builder: (context, state) => const AccountDetailsPage(),
        ),
        GoRoute(
          path: transactionDetailsPath,
          name: 'transaction_details',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return TransactionDetailsPage(transactionId: id);
          },
        ),
      ];
}
