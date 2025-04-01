import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:get_it/get_it.dart';

import 'di/dashboard_injector.dart';
import 'presentation/bloc/dashboard_bloc.dart';
import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/account_details_page.dart';
import 'presentation/pages/transaction_details_page.dart';


class DashboardMicroApp implements MicroApp {
  final GetIt _getIt;
  DashboardBloc? _dashboardBloc;
  bool _initialized = false;

  DashboardMicroApp({GetIt? getIt}) : _getIt = getIt ?? GetIt.instance;

  @override
  String get id => 'dashboard';

  @override
  String get name => 'Dashboard';

  @override
  bool get isInitialized => _initialized;

  
  DashboardBloc get dashboardBloc {
    if (!_initialized) {
      throw StateError(
          'DashboardMicroApp has not been initialized. Call initialize() first.');
    }
    return _dashboardBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/dashboard': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<DashboardBloc>.value(
            value: dashboardBloc,
            child: const DashboardPage(),
          );
        },
        '/dashboard/account': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<DashboardBloc>.value(
            value: dashboardBloc,
            child: const AccountDetailsPage(),
          );
        },
        '/dashboard/transaction/:id': (context, state) {
          _ensureInitialized();
          final id = state.params['id'] ?? '';
          return flutter_bloc.BlocProvider<DashboardBloc>.value(
            value: dashboardBloc,
            child: TransactionDetailsPage(transactionId: id),
          );
        },
      };

  
  void _ensureInitialized() {
    if (!_initialized) {
      
      DashboardInjector.register(_getIt);

      
      _dashboardBloc = _getIt<DashboardBloc>();
      _initialized = true;
    }
  }

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) return;

    
    DashboardInjector.register(_getIt);

    
    _dashboardBloc = _getIt<DashboardBloc>();

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return flutter_bloc.BlocProvider.value(
      value: dashboardBloc,
      child: const DashboardPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    registry.register(dashboardBloc);
  }

  @override
  Future<void> dispose() async {
    await dashboardBloc.close();
  }
}
