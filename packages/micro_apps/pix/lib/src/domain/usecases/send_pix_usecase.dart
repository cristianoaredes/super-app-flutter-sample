import 'package:core_interfaces/core_interfaces.dart';

import '../entities/pix_key.dart';
import '../entities/pix_transaction.dart';
import '../repositories/pix_repository.dart';


class SendPixUseCase {
  final PixRepository _repository;
  
  SendPixUseCase({required PixRepository repository})
      : _repository = repository;
  
  
  Future<PixTransaction> execute({
    required String pixKeyValue,
    required PixKeyType pixKeyType,
    required double amount,
    String? description,
    String? receiverName,
  }) {
    if (pixKeyValue.trim().isEmpty) {
      throw ValidationException(
        message: 'Chave Pix inválida',
        fieldErrors: const {'pixKeyValue': 'obrigatória'},
      );
    }
    if (amount <= 0) {
      throw ValidationException(
        message: 'Valor Pix inválido',
        fieldErrors: const {'amount': 'deve ser maior que zero'},
      );
    }
    return _repository.sendPix(
      pixKeyValue: pixKeyValue,
      pixKeyType: pixKeyType,
      amount: amount,
      description: description,
      receiverName: receiverName,
    );
  }
  
  
  Future<List<PixTransaction>> getPixTransactions() {
    return _repository.getPixTransactions();
  }
  
  
  Future<PixTransaction?> getPixTransactionById(String id) {
    return _repository.getPixTransactionById(id);
  }
}
