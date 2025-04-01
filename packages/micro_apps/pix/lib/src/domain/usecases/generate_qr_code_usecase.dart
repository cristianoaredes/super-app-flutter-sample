import '../entities/pix_qr_code.dart';
import '../repositories/pix_repository.dart';


class GenerateQrCodeUseCase {
  final PixRepository _repository;
  
  GenerateQrCodeUseCase({required PixRepository repository})
      : _repository = repository;
  
  
  Future<PixQrCode> execute({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) {
    return _repository.generateQrCode(
      pixKeyId: pixKeyId,
      amount: amount,
      description: description,
      isStatic: isStatic,
      expiresAt: expiresAt,
    );
  }
}
