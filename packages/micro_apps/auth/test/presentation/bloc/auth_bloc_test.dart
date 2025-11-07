import 'package:auth/src/domain/entities/user.dart';
import 'package:auth/src/domain/usecases/login_usecase.dart';
import 'package:auth/src/domain/usecases/logout_usecase.dart';
import 'package:auth/src/domain/usecases/register_usecase.dart';
import 'package:auth/src/domain/usecases/reset_password_usecase.dart';
import 'package:auth/src/presentation/bloc/auth_bloc.dart';
import 'package:auth/src/presentation/bloc/auth_event.dart';
import 'package:auth/src/presentation/bloc/auth_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_bloc_test.mocks.dart';

/// Gera os mocks necessários para os testes
/// Execute: dart run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  LoginUseCase,
  LogoutUseCase,
  RegisterUseCase,
  ResetPasswordUseCase,
  AnalyticsService,
])
void main() {
  late AuthBloc authBloc;
  late MockLoginUseCase mockLoginUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockRegisterUseCase mockRegisterUseCase;
  late MockResetPasswordUseCase mockResetPasswordUseCase;
  late MockAnalyticsService mockAnalyticsService;

  // Test data
  final testUser = User(
    id: 'test-id',
    name: 'Test User',
    email: 'test@example.com',
    createdAt: DateTime(2024, 1, 1),
    lastLogin: DateTime(2024, 1, 1),
  );

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockRegisterUseCase = MockRegisterUseCase();
    mockResetPasswordUseCase = MockResetPasswordUseCase();
    mockAnalyticsService = MockAnalyticsService();

    authBloc = AuthBloc(
      loginUseCase: mockLoginUseCase,
      logoutUseCase: mockLogoutUseCase,
      registerUseCase: mockRegisterUseCase,
      resetPasswordUseCase: mockResetPasswordUseCase,
      analyticsService: mockAnalyticsService,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    test('initial state should be AuthInitialState', () {
      expect(authBloc.state, equals(const AuthInitialState()));
    });

    group('CheckAuthStatusEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, UnauthenticatedState] when check auth status',
        build: () => authBloc,
        act: (bloc) => bloc.add(const CheckAuthStatusEvent()),
        expect: () => [
          const AuthLoadingState(),
          const UnauthenticatedState(),
        ],
      );
    });

    group('LoginWithEmailAndPasswordEvent', () {
      const testEmail = 'test@example.com';
      const testPassword = 'password123';

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthenticatedState] when login succeeds',
        build: () {
          when(mockLoginUseCase.executeWithEmailAndPassword(
            any,
            any,
          )).thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithEmailAndPasswordEvent(
          email: testEmail,
          password: testPassword,
        )),
        expect: () => [
          const AuthLoadingState(),
          AuthenticatedState(user: testUser),
        ],
        verify: (_) {
          verify(mockLoginUseCase.executeWithEmailAndPassword(
            testEmail,
            testPassword,
          )).called(1);
          verify(mockAnalyticsService.trackEvent(
            'login_success',
            {
              'method': 'email_password',
              'user_id': testUser.id,
            },
          )).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthErrorState] when login fails',
        build: () {
          when(mockLoginUseCase.executeWithEmailAndPassword(
            any,
            any,
          )).thenThrow(Exception('Invalid credentials'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithEmailAndPasswordEvent(
          email: testEmail,
          password: testPassword,
        )),
        expect: () => [
          const AuthLoadingState(),
          const AuthErrorState(message: 'Exception: Invalid credentials'),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'login_error',
            'Exception: Invalid credentials',
          )).called(1);
        },
      );
    });

    group('LoginWithGoogleEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthenticatedState] when Google login succeeds',
        build: () {
          when(mockLoginUseCase.executeWithGoogle())
              .thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithGoogleEvent()),
        expect: () => [
          const AuthLoadingState(),
          AuthenticatedState(user: testUser),
        ],
        verify: (_) {
          verify(mockLoginUseCase.executeWithGoogle()).called(1);
          verify(mockAnalyticsService.trackEvent(
            'login_success',
            {
              'method': 'google',
              'user_id': testUser.id,
            },
          )).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthErrorState] when Google login fails',
        build: () {
          when(mockLoginUseCase.executeWithGoogle())
              .thenThrow(Exception('Google login failed'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithGoogleEvent()),
        expect: () => [
          const AuthLoadingState(),
          const AuthErrorState(message: 'Exception: Google login failed'),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'login_error',
            'Exception: Google login failed',
          )).called(1);
        },
      );
    });

    group('LoginWithAppleEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthenticatedState] when Apple login succeeds',
        build: () {
          when(mockLoginUseCase.executeWithApple())
              .thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithAppleEvent()),
        expect: () => [
          const AuthLoadingState(),
          AuthenticatedState(user: testUser),
        ],
        verify: (_) {
          verify(mockLoginUseCase.executeWithApple()).called(1);
          verify(mockAnalyticsService.trackEvent(
            'login_success',
            {
              'method': 'apple',
              'user_id': testUser.id,
            },
          )).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthErrorState] when Apple login fails',
        build: () {
          when(mockLoginUseCase.executeWithApple())
              .thenThrow(Exception('Apple login failed'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const LoginWithAppleEvent()),
        expect: () => [
          const AuthLoadingState(),
          const AuthErrorState(message: 'Exception: Apple login failed'),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'login_error',
            'Exception: Apple login failed',
          )).called(1);
        },
      );
    });

    group('LogoutEvent', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, UnauthenticatedState] when logout succeeds',
        build: () {
          when(mockLogoutUseCase.execute()).thenAnswer((_) async => {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const LogoutEvent()),
        expect: () => [
          const AuthLoadingState(),
          const UnauthenticatedState(),
        ],
        verify: (_) {
          verify(mockLogoutUseCase.execute()).called(1);
          verify(mockAnalyticsService.trackEvent('logout', {})).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthErrorState] when logout fails',
        build: () {
          when(mockLogoutUseCase.execute())
              .thenThrow(Exception('Logout failed'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const LogoutEvent()),
        expect: () => [
          const AuthLoadingState(),
          const AuthErrorState(message: 'Exception: Logout failed'),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'logout_error',
            'Exception: Logout failed',
          )).called(1);
        },
      );
    });

    group('RegisterEvent', () {
      const testName = 'Test User';
      const testEmail = 'test@example.com';
      const testPassword = 'password123';

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, RegisterSuccessState] when register succeeds',
        build: () {
          when(mockRegisterUseCase.execute(
            any,
            any,
            any,
          )).thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const RegisterEvent(
          name: testName,
          email: testEmail,
          password: testPassword,
        )),
        expect: () => [
          const AuthLoadingState(),
          RegisterSuccessState(user: testUser),
        ],
        verify: (_) {
          verify(mockRegisterUseCase.execute(
            testName,
            testEmail,
            testPassword,
          )).called(1);
          verify(mockAnalyticsService.trackEvent(
            'register_success',
            {'user_id': testUser.id},
          )).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthErrorState] when register fails',
        build: () {
          when(mockRegisterUseCase.execute(
            any,
            any,
            any,
          )).thenThrow(Exception('Email already exists'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const RegisterEvent(
          name: testName,
          email: testEmail,
          password: testPassword,
        )),
        expect: () => [
          const AuthLoadingState(),
          const AuthErrorState(message: 'Exception: Email already exists'),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'register_error',
            'Exception: Email already exists',
          )).called(1);
        },
      );
    });

    group('ResetPasswordEvent', () {
      const testEmail = 'test@example.com';

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, ResetPasswordSuccessState] when reset succeeds',
        build: () {
          when(mockResetPasswordUseCase.execute(any))
              .thenAnswer((_) async => {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const ResetPasswordEvent(email: testEmail)),
        expect: () => [
          const AuthLoadingState(),
          const ResetPasswordSuccessState(),
        ],
        verify: (_) {
          verify(mockResetPasswordUseCase.execute(testEmail)).called(1);
          verify(mockAnalyticsService.trackEvent(
            'reset_password_success',
            {'email': testEmail},
          )).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoadingState, AuthErrorState] when reset fails',
        build: () {
          when(mockResetPasswordUseCase.execute(any))
              .thenThrow(Exception('Email not found'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const ResetPasswordEvent(email: testEmail)),
        expect: () => [
          const AuthLoadingState(),
          const AuthErrorState(message: 'Exception: Email not found'),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'reset_password_error',
            'Exception: Email not found',
          )).called(1);
        },
      );
    });
  });
}
