import 'package:auth/src/domain/entities/user.dart';
import 'package:auth/src/domain/repositories/auth_repository.dart';
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

final _user = User(
  id: 'u1',
  name: 'Test',
  email: 'user@example.com',
  createdAt: DateTime(2024, 1, 1),
);

class _FakeAuthService implements AuthService {
  bool authenticated = false;
  String? userId;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<String?> get accessToken async => authenticated ? 'session' : null;

  @override
  String? get currentUserId => userId;

  @override
  void establishSession({required String userId, String? accessToken}) {
    this.userId = userId;
    authenticated = true;
  }

  @override
  Future<bool> login(String username, String password) async => false;

  @override
  Future<void> logout() async {
    authenticated = false;
    userId = null;
  }

  @override
  Future<bool> refreshToken() async => false;
}

class _FakeRepo implements AuthRepository {
  _FakeRepo({this.user, this.token});

  User? user;
  String? token;
  User? lastLogin;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<User?> getCurrentUser() async => user;

  @override
  Future<bool> isAuthenticated() async => token != null;

  @override
  Future<User> loginWithEmailAndPassword(String email, String password) async {
    lastLogin = _user;
    user = _user;
    token = 'session_u1';
    return _user;
  }

  @override
  Future<User> loginWithApple() => throw UnimplementedError();

  @override
  Future<User> loginWithGoogle() => throw UnimplementedError();

  @override
  Future<void> logout() async {
    user = null;
    token = null;
  }

  @override
  Future<String?> refreshToken() async => token;

  @override
  Future<User> register(String name, String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _Login extends LoginUseCase {
  _Login(AuthRepository repo) : super(repository: repo);
}

class _Logout extends LogoutUseCase {
  _Logout(AuthRepository repo) : super(repository: repo);
}

class _Register extends RegisterUseCase {
  _Register(AuthRepository repo) : super(repository: repo);
}

class _Reset extends ResetPasswordUseCase {
  _Reset(AuthRepository repo) : super(repository: repo);
}

class _Analytics implements AnalyticsService {
  final events = <String>[];

  @override
  Future<void> trackEvent(String eventName, Map<String, dynamic> parameters) async {
    events.add(eventName);
  }

  @override
  Future<void> trackError(String errorName, String errorMessage,
      {StackTrace? stackTrace}) async {
    events.add('error:$errorName');
  }

  @override
  Future<void> setUserId(String userId) async {}

  @override
  Future<void> setUserProperties(Map<String, dynamic> properties) async {}

  @override
  Future<void> startSession() async {}

  @override
  Future<void> endSession() async {}
}

void main() {
  late _FakeAuthService authService;
  late _FakeRepo repo;
  late _Analytics analytics;

  AuthBloc buildBloc() {
    return AuthBloc(
      loginUseCase: _Login(repo),
      logoutUseCase: _Logout(repo),
      registerUseCase: _Register(repo),
      resetPasswordUseCase: _Reset(repo),
      analyticsService: analytics,
      authService: authService,
      authRepository: repo,
    );
  }

  setUp(() {
    authService = _FakeAuthService();
    repo = _FakeRepo();
    analytics = _Analytics();
  });

  blocTest<AuthBloc, AuthState>(
    'check status is unauthenticated without a token',
    build: buildBloc,
    act: (bloc) => bloc.add(const CheckAuthStatusEvent()),
    expect: () => [
      const AuthLoadingState(),
      const UnauthenticatedState(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'check status authenticates when repository has a user and token',
    setUp: () {
      repo.user = _user;
      repo.token = 'session_u1';
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const CheckAuthStatusEvent()),
    expect: () => [
      const AuthLoadingState(),
      AuthenticatedState(user: _user),
    ],
    verify: (_) {
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUserId, 'u1');
    },
  );

  blocTest<AuthBloc, AuthState>(
    'email login establishes the host session',
    build: buildBloc,
    act: (bloc) => bloc.add(const LoginWithEmailAndPasswordEvent(
      email: 'user@example.com',
      password: 'password',
    )),
    expect: () => [
      const AuthLoadingState(),
      AuthenticatedState(user: _user),
    ],
    verify: (_) {
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUserId, 'u1');
      expect(analytics.events, contains('login_success'));
    },
  );
}
