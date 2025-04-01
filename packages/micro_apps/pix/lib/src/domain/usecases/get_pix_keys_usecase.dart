import '../entities/pix_key.dart';
import '../repositories/pix_repository.dart';


class GetPixKeysUseCase {
  final PixRepository _repository;
  
  GetPixKeysUseCase({required PixRepository repository})
      : _repository = repository;
  
  
  Future<List<PixKey>> execute() {
    return _repository.getPixKeys();
  }
  
  
  Future<PixKey?> getPixKeyById(String id) {
    return _repository.getPixKeyById(id);
  }
}
