import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as flutter_bloc;
import 'package:get_it/get_it.dart';

import 'di/auth_injector.dart';
import 'presentation/bloc/auth_bloc.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/register_page.dart';
import 'presentation/pages/reset_password_page.dart';

/// Micro app de autenticação
///
/// Gerencia funcionalidades de:
/// - Login com email/senha
/// - Registro de novos usuários
/// - Recuperação de senha
/// - Login social (Google, Apple)
///
/// ## Credenciais de Teste
///
/// - Email: user@example.com
/// - Senha: password
class AuthMicroApp extends BaseMicroApp {
  AuthBloc? _authBloc;

  AuthMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'auth';

  @override
  String get name => 'Auth';

  /// Retorna a instância do AuthBloc
  ///
  /// Throws [InvalidStateException] se o micro app não foi inicializado.
  AuthBloc get authBloc {
    ensureInitialized();
    return _authBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
        '/login': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const LoginPage(),
          );
        },
        '/register': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const RegisterPage(),
          );
        },
        '/reset-password': (context, state) {
          ensureInitialized();
          return flutter_bloc.BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const ResetPasswordPage(),
          );
        },
      };

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Registrar dependências do módulo de autenticação
    AuthInjector.register(getIt);

    // Criar instância do AuthBloc
    _authBloc = getIt<AuthBloc>();
  }

  @override
  Future<void> onDispose() async {
    if (_authBloc != null) {
      await _authBloc!.close();
      _authBloc = null;
    }
  }

  @override
  Future<bool> checkHealth() async {
    if (_authBloc == null) {
      return false;
    }

    try {
      // Verifica se o BLoC está em estado válido
      final state = _authBloc!.state;
      return state != null;
    } catch (e) {
      dependencies.loggingService?.error(
        'Health check falhou para AuthBloc',
        error: e,
        tag: 'AuthMicroApp',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return flutter_bloc.BlocProvider.value(
      value: authBloc,
      child: const LoginPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register(authBloc);
  }
}
