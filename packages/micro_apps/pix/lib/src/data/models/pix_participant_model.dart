import '../../domain/entities/pix_transaction.dart';
import '../../domain/entities/pix_key.dart';
import 'pix_key_model.dart';


class PixParticipantModel extends PixParticipant {
  const PixParticipantModel({
    required super.name,
    required super.document,
    required super.bank,
    super.agency,
    super.account,
    super.pixKey,
  });

  
  factory PixParticipantModel.fromJson(Map<String, dynamic> json) {
    return PixParticipantModel(
      name: json['name'] as String,
      document: json['document'] as String,
      bank: json['bank'] as String,
      agency: json['agency'] as String?,
      account: json['account'] as String?,
      pixKey: json['pix_key'] != null
          ? PixKeyModel.fromJson(json['pix_key'] as Map<String, dynamic>)
          : null,
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'document': document,
      'bank': bank,
      'agency': agency,
      'account': account,
      'pix_key': pixKey != null ? (pixKey as PixKeyModel).toJson() : null,
    };
  }

  
  @override
  PixParticipant copyWith({
    String? name,
    String? document,
    String? bank,
    String? agency,
    String? account,
    PixKey? pixKey,
  }) {
    return PixParticipantModel(
      name: name ?? this.name,
      document: document ?? this.document,
      bank: bank ?? this.bank,
      agency: agency ?? this.agency,
      account: account ?? this.account,
      pixKey: pixKey ?? this.pixKey,
    );
  }
}
