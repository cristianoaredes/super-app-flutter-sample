import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final RegisterUseCase _registerUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final AnalyticsService _analyticsService;
  final AuthService? _authService;
  final AuthRepository? _authRepository;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required RegisterUseCase registerUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required AnalyticsService analyticsService,
    AuthService? authService,
    AuthRepository? authRepository,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _registerUseCase = registerUseCase,
        _resetPasswordUseCase = resetPasswordUseCase,
        _analyticsService = analyticsService,
        _authService = authService,
        _authRepository = authRepository,
        super(const AuthInitialState()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginWithEmailAndPasswordEvent>(_onLoginWithEmailAndPassword);
    on<LoginWithGoogleEvent>(_onLoginWithGoogle);
    on<LoginWithAppleEvent>(_onLoginWithApple);
    on<LogoutEvent>(_onLogout);
    on<RegisterEvent>(_onRegister);
    on<ResetPasswordEvent>(_onResetPassword);
  }
  
  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());

    try {
      final repositoryAuthenticated =
          await _authRepository?.isAuthenticated() ?? false;
      final hostAuthenticated = _authService?.isAuthenticated ?? false;

      if (!repositoryAuthenticated && !hostAuthenticated) {
        emit(const UnauthenticatedState());
        return;
      }

      final user = await _authRepository?.getCurrentUser();
      if (user != null) {
        _syncHostSession(user.id);
        emit(AuthenticatedState(user: user));
        return;
      }

      emit(const UnauthenticatedState());
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  void _syncHostSession(String userId) {
    _authService?.establishSession(userId: userId);
  }

  Future<void> _onLoginWithEmailAndPassword(
    LoginWithEmailAndPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    try {
      final user = await _loginUseCase.executeWithEmailAndPassword(
        event.email,
        event.password,
      );
      
      _analyticsService.trackEvent(
        'login_success',
        {
          'method': 'email_password',
          'user_id': user.id,
        },
      );
      
      _syncHostSession(user.id);
      emit(AuthenticatedState(user: user));
    } catch (e) {
      _analyticsService.trackError(
        'login_error',
        e.toString(),
      );
      
      emit(AuthErrorState(message: e.toString()));
    }
  }
  
  Future<void> _onLoginWithGoogle(
    LoginWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    try {
      final user = await _loginUseCase.executeWithGoogle();
      
      _analyticsService.trackEvent(
        'login_success',
        {
          'method': 'google',
          'user_id': user.id,
        },
      );
      
      _syncHostSession(user.id);
      emit(AuthenticatedState(user: user));
    } catch (e) {
      _analyticsService.trackError(
        'login_error',
        e.toString(),
      );
      
      emit(AuthErrorState(message: e.toString()));
    }
  }
  
  Future<void> _onLoginWithApple(
    LoginWithAppleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    try {
      final user = await _loginUseCase.executeWithApple();
      
      _analyticsService.trackEvent(
        'login_success',
        {
          'method': 'apple',
          'user_id': user.id,
        },
      );
      
      _syncHostSession(user.id);
      emit(AuthenticatedState(user: user));
    } catch (e) {
      _analyticsService.trackError(
        'login_error',
        e.toString(),
      );
      
      emit(AuthErrorState(message: e.toString()));
    }
  }
  
  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    try {
      await _logoutUseCase.execute();
      await _authService?.logout();

      _analyticsService.trackEvent(
        'logout',
        {},
      );
      
      emit(const UnauthenticatedState());
    } catch (e) {
      _analyticsService.trackError(
        'logout_error',
        e.toString(),
      );
      
      emit(AuthErrorState(message: e.toString()));
    }
  }
  
  Future<void> _onRegister(
    RegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    try {
      final user = await _registerUseCase.execute(
        event.name,
        event.email,
        event.password,
      );
      
      _analyticsService.trackEvent(
        'register_success',
        {
          'user_id': user.id,
        },
      );
      
      _syncHostSession(user.id);
      emit(RegisterSuccessState(user: user));
    } catch (e) {
      _analyticsService.trackError(
        'register_error',
        e.toString(),
      );
      
      emit(AuthErrorState(message: e.toString()));
    }
  }
  
  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    try {
      await _resetPasswordUseCase.execute(event.email);
      
      _analyticsService.trackEvent(
        'reset_password_success',
        {
          'email': event.email,
        },
      );
      
      emit(const ResetPasswordSuccessState());
    } catch (e) {
      _analyticsService.trackError(
        'reset_password_error',
        e.toString(),
      );
      
      emit(AuthErrorState(message: e.toString()));
    }
  }
}
