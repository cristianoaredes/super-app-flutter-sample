import '../repositories/pix_repository.dart';


class DeletePixKeyUseCase {
  final PixRepository _repository;
  
  DeletePixKeyUseCase({required PixRepository repository})
      : _repository = repository;
  
  
  Future<void> execute(String id) {
    return _repository.deletePixKey(id);
  }
}
