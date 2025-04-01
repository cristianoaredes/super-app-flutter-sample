import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) {
      _currentIndex = 0;
    } else if (location.startsWith('/pix')) {
      _currentIndex = 1;
    } else if (location.startsWith('/payments')) {
      _currentIndex = 2;
    } else if (location.startsWith('/cards')) {
      _currentIndex = 3;
    } else if (location.startsWith('/account')) {
      _currentIndex = 4;
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          
          switch (index) {
            case 0:
              GoRouter.of(context).go('/dashboard');
              break;
            case 1:
              GoRouter.of(context).go('/pix');
              break;
            case 2:
              GoRouter.of(context).go('/payments');
              break;
            case 3:
              GoRouter.of(context).go('/cards');
              break;
            case 4:
              GoRouter.of(context).go('/account');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Pix',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            selectedIcon: Icon(Icons.payment),
            label: 'Pagamentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Cartões',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Conta',
          ),
        ],
      ),
    );
  }
}
