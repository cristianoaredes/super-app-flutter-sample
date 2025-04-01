import '../entities/pix_key.dart';
import '../entities/pix_transaction.dart';
import '../entities/pix_qr_code.dart';


abstract class PixRepository {
  
  Future<List<PixKey>> getPixKeys();
  
  
  Future<PixKey?> getPixKeyById(String id);
  
  
  Future<PixKey> registerPixKey(PixKeyType type, String value, {String? name});
  
  
  Future<void> deletePixKey(String id);
  
  
  Future<List<PixTransaction>> getPixTransactions();
  
  
  Future<PixTransaction?> getPixTransactionById(String id);
  
  
  Future<PixTransaction> sendPix({
    required String pixKeyValue,
    required PixKeyType pixKeyType,
    required double amount,
    String? description,
    String? receiverName,
  });
  
  
  Future<PixQrCode> receivePixWithQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  });
  
  
  Future<PixQrCode> generateQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  });
  
  
  Future<PixQrCode> readQrCode(String payload);
}
