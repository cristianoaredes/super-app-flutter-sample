import 'package:core_interfaces/core_interfaces.dart';

class AuthServiceImpl implements AuthService {
  String? _accessToken;
  String? _userId;
  bool _isAuthenticated = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<String?> get accessToken async => _accessToken;

  @override
  String? get currentUserId => _userId;

  @override
  Future<bool> login(String username, String password) async {
    
    await Future.delayed(const Duration(seconds: 1));

    if (username == 'user@example.com' && password == 'password') {
      _accessToken = 'fake_token';
      _userId = 'user_123';
      _isAuthenticated = true;
      return true;
    }

    return false;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));

    _accessToken = null;
    _userId = null;
    _isAuthenticated = false;
  }

  @override
  Future<bool> refreshToken() async {
    
    await Future.delayed(const Duration(seconds: 1));

    if (_isAuthenticated) {
      _accessToken = 'new_fake_token';
      return true;
    }

    return false;
  }
}
