import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'di/account_injector.dart';
import 'presentation/bloc/account_bloc.dart';
import 'presentation/pages/account_page.dart';
import 'presentation/pages/account_details_page.dart';
import 'presentation/pages/account_statement_page.dart';
import 'presentation/pages/transfer_page.dart';


class AccountMicroApp implements MicroApp {
  final GetIt _getIt;
  AccountBloc? _accountBloc;
  bool _initialized = false;

  AccountMicroApp({GetIt? getIt}) : _getIt = getIt ?? GetIt.instance;

  @override
  String get id => 'account';

  @override
  String get name => 'Conta';

  @override
  bool get isInitialized => _initialized;

  
  AccountBloc get accountBloc {
    if (!_initialized) {
      throw StateError(
          'AccountMicroApp não foi inicializado. Chame initialize() primeiro.');
    }
    return _accountBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/account': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<AccountBloc>.value(
            value: accountBloc,
            child: const AccountPage(),
          );
        },
        '/account/details': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<AccountBloc>.value(
            value: accountBloc,
            child: const AccountDetailsPage(),
          );
        },
        '/account/statement': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<AccountBloc>.value(
            value: accountBloc,
            child: const AccountStatementPage(),
          );
        },
        '/account/transfer': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<AccountBloc>.value(
            value: accountBloc,
            child: const TransferPage(),
          );
        },
      };

  
  void _ensureInitialized() {
    if (!_initialized) {
      
      AccountInjector.register(_getIt);
      _accountBloc = _getIt<AccountBloc>();
      _initialized = true;
    }
  }

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) return;

    
    AccountInjector.register(_getIt);
    _accountBloc = _getIt<AccountBloc>();

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialized();
    return flutter_bloc.BlocProvider.value(
      value: accountBloc,
      child: const AccountPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    _ensureInitialized();
    registry.register(accountBloc);
  }

  @override
  Future<void> dispose() async {
    if (_initialized && _accountBloc != null) {
      await _accountBloc!.close();
    }
  }
}
