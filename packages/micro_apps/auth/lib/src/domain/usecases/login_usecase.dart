import '../entities/user.dart';
import '../repositories/auth_repository.dart';


class LoginUseCase {
  final AuthRepository _repository;
  
  LoginUseCase({required AuthRepository repository}) : _repository = repository;
  
  
  Future<User> executeWithEmailAndPassword(String email, String password) {
    return _repository.loginWithEmailAndPassword(email, password);
  }
  
  
  Future<User> executeWithGoogle() {
    return _repository.loginWithGoogle();
  }
  
  
  Future<User> executeWithApple() {
    return _repository.loginWithApple();
  }
}
