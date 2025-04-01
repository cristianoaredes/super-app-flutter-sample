import '../repositories/auth_repository.dart';


class ResetPasswordUseCase {
  final AuthRepository _repository;
  
  ResetPasswordUseCase({required AuthRepository repository}) : _repository = repository;
  
  
  Future<void> execute(String email) {
    return _repository.sendPasswordResetEmail(email);
  }
}
