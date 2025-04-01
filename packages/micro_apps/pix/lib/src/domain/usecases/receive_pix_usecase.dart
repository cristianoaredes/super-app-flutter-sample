import '../entities/pix_qr_code.dart';
import '../repositories/pix_repository.dart';


class ReceivePixUseCase {
  final PixRepository _repository;
  
  ReceivePixUseCase({required PixRepository repository})
      : _repository = repository;
  
  
  Future<PixQrCode> execute({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) {
    return _repository.receivePixWithQrCode(
      pixKeyId: pixKeyId,
      amount: amount,
      description: description,
      isStatic: isStatic,
      expiresAt: expiresAt,
    );
  }
}
