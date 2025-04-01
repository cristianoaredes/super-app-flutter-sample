import 'package:flutter/material.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';

import '../../di/navigation_service_locator.dart';


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    
    final navigationService = NavigationServiceLocator.getNavigationService();

    
    final authService = GetIt.instance<AuthService>();

    
    if (authService.isAuthenticated) {
      
      navigationService.navigateTo('/dashboard');
    } else {
      
      navigationService.navigateTo('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            Container(
              width: 120.0,
              height: 120.0,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance,
                size: 64.0,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              'Super App',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 48.0),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
