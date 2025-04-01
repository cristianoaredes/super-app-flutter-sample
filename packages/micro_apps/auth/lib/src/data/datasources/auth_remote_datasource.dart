import 'package:core_interfaces/core_interfaces.dart';

import '../models/user_model.dart';


abstract class AuthRemoteDataSource {
  
  Future<UserModel> loginWithEmailAndPassword(String email, String password);

  
  Future<UserModel> loginWithGoogle();

  
  Future<UserModel> loginWithApple();

  
  Future<UserModel> register(String name, String email, String password);

  
  Future<void> sendPasswordResetEmail(String email);

  
  Future<String?> refreshToken();
}


class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<UserModel> loginWithEmailAndPassword(
      String email, String password) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to login');
    }

    return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    final response = await _apiClient.post('/auth/google');

    if (response.statusCode != 200) {
      throw Exception('Failed to login with Google');
    }

    return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> loginWithApple() async {
    final response = await _apiClient.post('/auth/apple');

    if (response.statusCode != 200) {
      throw Exception('Failed to login with Apple');
    }

    return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> register(String name, String email, String password) async {
    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to register user');
    }

    return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final response = await _apiClient.post(
      '/auth/reset-password',
      body: {
        'email': email,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send password reset email');
    }
  }

  @override
  Future<String?> refreshToken() async {
    final response = await _apiClient.post('/auth/refresh-token');

    if (response.statusCode != 200) {
      return null;
    }

    return response.data['token'] as String?;
  }
}
