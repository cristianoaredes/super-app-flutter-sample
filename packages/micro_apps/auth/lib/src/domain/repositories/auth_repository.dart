import '../entities/user.dart';


abstract class AuthRepository {
  
  Future<User?> getCurrentUser();
  
  
  Future<bool> isAuthenticated();
  
  
  Future<User> loginWithEmailAndPassword(String email, String password);
  
  
  Future<User> loginWithGoogle();
  
  
  Future<User> loginWithApple();
  
  
  Future<void> logout();
  
  
  Future<User> register(String name, String email, String password);
  
  
  Future<void> sendPasswordResetEmail(String email);
  
  
  Future<String?> refreshToken();
  
  
  Future<String?> getAccessToken();
}
