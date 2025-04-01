import '../entities/pix_qr_code.dart';
import '../repositories/pix_repository.dart';


class ReadQrCodeUseCase {
  final PixRepository _repository;
  
  ReadQrCodeUseCase({required PixRepository repository})
      : _repository = repository;
  
  
  Future<PixQrCode> execute(String payload) {
    return _repository.readQrCode(payload);
  }
}
