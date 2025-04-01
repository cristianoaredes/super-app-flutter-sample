import '../../domain/entities/card.dart';


class CardModel extends Card {
  const CardModel({
    required super.id,
    required super.number,
    required super.holderName,
    required super.type,
    required super.brand,
    required super.expirationDate,
    required super.cvv,
    required super.limit,
    required super.availableLimit,
    required super.isBlocked,
    required super.isVirtual,
    required super.isContactless,
    required super.status,
  });
  
  
  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as String,
      number: json['number'] as String,
      holderName: json['holder_name'] as String,
      type: json['type'] as String,
      brand: json['brand'] as String,
      expirationDate: DateTime.parse(json['expiration_date'] as String),
      cvv: json['cvv'] as String,
      limit: (json['limit'] as num).toDouble(),
      availableLimit: (json['available_limit'] as num).toDouble(),
      isBlocked: json['is_blocked'] as bool,
      isVirtual: json['is_virtual'] as bool,
      isContactless: json['is_contactless'] as bool,
      status: _parseCardStatus(json['status'] as String),
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'holder_name': holderName,
      'type': type,
      'brand': brand,
      'expiration_date': expirationDate.toIso8601String(),
      'cvv': cvv,
      'limit': limit,
      'available_limit': availableLimit,
      'is_blocked': isBlocked,
      'is_virtual': isVirtual,
      'is_contactless': isContactless,
      'status': _cardStatusToString(status),
    };
  }
  
  
  @override
  CardModel copyWith({
    String? id,
    String? number,
    String? holderName,
    String? type,
    String? brand,
    DateTime? expirationDate,
    String? cvv,
    double? limit,
    double? availableLimit,
    bool? isBlocked,
    bool? isVirtual,
    bool? isContactless,
    CardStatus? status,
  }) {
    return CardModel(
      id: id ?? this.id,
      number: number ?? this.number,
      holderName: holderName ?? this.holderName,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      expirationDate: expirationDate ?? this.expirationDate,
      cvv: cvv ?? this.cvv,
      limit: limit ?? this.limit,
      availableLimit: availableLimit ?? this.availableLimit,
      isBlocked: isBlocked ?? this.isBlocked,
      isVirtual: isVirtual ?? this.isVirtual,
      isContactless: isContactless ?? this.isContactless,
      status: status ?? this.status,
    );
  }
  
  
  static CardStatus _parseCardStatus(String status) {
    switch (status) {
      case 'active':
        return CardStatus.active;
      case 'inactive':
        return CardStatus.inactive;
      case 'blocked':
        return CardStatus.blocked;
      case 'expired':
        return CardStatus.expired;
      case 'canceled':
        return CardStatus.canceled;
      default:
        return CardStatus.inactive;
    }
  }
  
  
  static String _cardStatusToString(CardStatus status) {
    switch (status) {
      case CardStatus.active:
        return 'active';
      case CardStatus.inactive:
        return 'inactive';
      case CardStatus.blocked:
        return 'blocked';
      case CardStatus.expired:
        return 'expired';
      case CardStatus.canceled:
        return 'canceled';
    }
  }
}
