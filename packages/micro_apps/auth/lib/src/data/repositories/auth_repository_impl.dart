import 'package:core_interfaces/core_interfaces.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';


class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final NetworkService _networkService;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required NetworkService networkService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkService = networkService;

  
  bool get _isMockDataSource =>
      _remoteDataSource.runtimeType.toString().contains('Mock');

  
  Future<void> _checkInternetConnection() async {
    
    if (_isMockDataSource) return;

    final hasInternet = await _networkService.hasInternetConnection;
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    return _localDataSource.getUser();
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await _localDataSource.getAccessToken();
    return token != null;
  }

  @override
  Future<User> loginWithEmailAndPassword(String email, String password) async {
    await _checkInternetConnection();

    final user =
        await _remoteDataSource.loginWithEmailAndPassword(email, password);

    
    await _localDataSource.saveUser(user);

    return user;
  }

  @override
  Future<User> loginWithGoogle() async {
    await _checkInternetConnection();

    final user = await _remoteDataSource.loginWithGoogle();

    
    await _localDataSource.saveUser(user);

    return user;
  }

  @override
  Future<User> loginWithApple() async {
    await _checkInternetConnection();

    final user = await _remoteDataSource.loginWithApple();

    
    await _localDataSource.saveUser(user);

    return user;
  }

  @override
  Future<void> logout() async {
    await _localDataSource.removeUser();
    await _localDataSource.removeAccessToken();
  }

  @override
  Future<User> register(String name, String email, String password) async {
    await _checkInternetConnection();

    final user = await _remoteDataSource.register(name, email, password);

    
    await _localDataSource.saveUser(user);

    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _checkInternetConnection();

    await _remoteDataSource.sendPasswordResetEmail(email);
  }

  @override
  Future<String?> refreshToken() async {
    
    if (!_isMockDataSource) {
      final hasInternet = await _networkService.hasInternetConnection;
      if (!hasInternet) {
        return null;
      }
    }

    final token = await _remoteDataSource.refreshToken();

    if (token != null) {
      await _localDataSource.saveAccessToken(token);
    }

    return token;
  }

  @override
  Future<String?> getAccessToken() async {
    return _localDataSource.getAccessToken();
  }
}
