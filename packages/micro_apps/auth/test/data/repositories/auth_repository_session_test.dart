import 'package:auth/src/data/datasources/auth_local_datasource.dart';
import 'package:auth/src/data/datasources/auth_remote_datasource.dart';
import 'package:auth/src/data/models/user_model.dart';
import 'package:auth/src/data/repositories/auth_repository_impl.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';

class _Remote implements AuthRemoteDataSource {
  @override
  Future<UserModel> loginWithEmailAndPassword(
      String email, String password) async {
    return UserModel(
      id: 'u1',
      name: 'Test',
      email: email,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  @override
  Future<UserModel> loginWithApple() => throw UnimplementedError();

  @override
  Future<UserModel> loginWithGoogle() => throw UnimplementedError();

  @override
  Future<String?> refreshToken() async => null;

  @override
  Future<UserModel> register(String name, String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _Local implements AuthLocalDataSource {
  String? userJsonId;
  String? token;

  @override
  Future<UserModel?> getUser() async => null;

  @override
  Future<void> saveUser(UserModel user) async {
    userJsonId = user.id;
  }

  @override
  Future<void> removeUser() async {
    userJsonId = null;
  }

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> saveAccessToken(String value) async {
    token = value;
  }

  @override
  Future<void> removeAccessToken() async {
    token = null;
  }
}

class _Net implements NetworkService {
  @override
  Future<bool> get hasInternetConnection async => true;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('login persists user and a session token', () async {
    final local = _Local();
    final repo = AuthRepositoryImpl(
      remoteDataSource: _Remote(),
      localDataSource: local,
      networkService: _Net(),
    );

    final user =
        await repo.loginWithEmailAndPassword('user@example.com', 'password');

    expect(user.id, 'u1');
    expect(local.userJsonId, 'u1');
    expect(local.token, 'session_u1');
    expect(await repo.isAuthenticated(), isTrue);
  });
}
