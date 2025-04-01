
abstract class AuthService {
  
  bool get isAuthenticated;

  
  Future<String?> get accessToken;

  
  Future<bool> login(String username, String password);

  
  Future<void> logout();

  
  Future<bool> refreshToken();

  
  String? get currentUserId;
}
