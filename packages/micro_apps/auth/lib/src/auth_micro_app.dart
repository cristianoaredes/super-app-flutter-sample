import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:get_it/get_it.dart';

import 'di/auth_injector.dart';
import 'presentation/bloc/auth_bloc.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/register_page.dart';
import 'presentation/pages/reset_password_page.dart';


class AuthMicroApp implements MicroApp {
  final GetIt _getIt;
  AuthBloc? _authBloc;
  bool _initialized = false;

  AuthMicroApp({GetIt? getIt}) : _getIt = getIt ?? GetIt.instance;

  @override
  String get id => 'auth';

  @override
  String get name => 'Auth';

  @override
  bool get isInitialized => _initialized;

  
  AuthBloc get authBloc {
    if (!_initialized) {
      throw StateError(
          'AuthMicroApp não foi inicializado. Chame initialize() primeiro.');
    }
    return _authBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/login': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const LoginPage(),
          );
        },
        '/register': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const RegisterPage(),
          );
        },
        '/reset-password': (context, state) {
          _ensureInitialized();
          return flutter_bloc.BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const ResetPasswordPage(),
          );
        },
      };

  
  void _ensureInitialized() {
    if (!_initialized) {
      
      AuthInjector.register(_getIt);

      
      _authBloc = _getIt<AuthBloc>();
      _initialized = true;
    }
  }

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) return;

    
    AuthInjector.register(_getIt);

    
    _authBloc = _getIt<AuthBloc>();

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialized();
    return flutter_bloc.BlocProvider.value(
      value: authBloc,
      child: const LoginPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    _ensureInitialized();
    registry.register(authBloc);
  }

  @override
  Future<void> dispose() async {
    if (_initialized && _authBloc != null) {
      await _authBloc!.close();
    }
  }
}
