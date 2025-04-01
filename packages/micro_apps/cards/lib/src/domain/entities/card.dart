import 'package:equatable/equatable.dart';


class Card extends Equatable {
  final String id;
  final String number;
  final String holderName;
  final String type;
  final String brand;
  final DateTime expirationDate;
  final String cvv;
  final double limit;
  final double availableLimit;
  final bool isBlocked;
  final bool isVirtual;
  final bool isContactless;
  final CardStatus status;
  
  const Card({
    required this.id,
    required this.number,
    required this.holderName,
    required this.type,
    required this.brand,
    required this.expirationDate,
    required this.cvv,
    required this.limit,
    required this.availableLimit,
    required this.isBlocked,
    required this.isVirtual,
    required this.isContactless,
    required this.status,
  });
  
  @override
  List<Object?> get props => [
    id,
    number,
    holderName,
    type,
    brand,
    expirationDate,
    cvv,
    limit,
    availableLimit,
    isBlocked,
    isVirtual,
    isContactless,
    status,
  ];
  
  
  Card copyWith({
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
    return Card(
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
  
  
  String get maskedNumber {
    if (number.length < 16) {
      return number;
    }
    
    return '${number.substring(0, 4)} **** **** ${number.substring(12)}';
  }
  
  
  bool get isActive => status == CardStatus.active;
  
  
  bool get isExpired => expirationDate.isBefore(DateTime.now());
}


enum CardStatus {
  active,
  inactive,
  blocked,
  expired,
  canceled,
}
