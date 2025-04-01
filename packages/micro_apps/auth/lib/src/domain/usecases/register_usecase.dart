import '../entities/user.dart';
import '../repositories/auth_repository.dart';


class RegisterUseCase {
  final AuthRepository _repository;
  
  RegisterUseCase({required AuthRepository repository}) : _repository = repository;
  
  
  Future<User> execute(String name, String email, String password) {
    return _repository.register(name, email, password);
  }
}
