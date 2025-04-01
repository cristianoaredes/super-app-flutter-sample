import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

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
  
  AuthBloc({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required RegisterUseCase registerUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required AnalyticsService analyticsService,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _registerUseCase = registerUseCase,
        _resetPasswordUseCase = resetPasswordUseCase,
        _analyticsService = analyticsService,
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
      
      
      
      
      
      
      
      
      
      
      
      
      
      emit(const UnauthenticatedState());
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
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
