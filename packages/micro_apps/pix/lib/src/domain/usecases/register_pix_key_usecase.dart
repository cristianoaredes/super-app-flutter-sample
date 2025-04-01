import '../entities/pix_key.dart';
import '../repositories/pix_repository.dart';


class RegisterPixKeyUseCase {
  final PixRepository _repository;
  
  RegisterPixKeyUseCase({required PixRepository repository})
      : _repository = repository;
  
  
  Future<PixKey> execute(PixKeyType type, String value, {String? name}) {
    return _repository.registerPixKey(type, value, name: name);
  }
}
