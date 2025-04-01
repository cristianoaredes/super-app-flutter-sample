import 'package:equatable/equatable.dart';


class Account extends Equatable {
  final String id;
  final String number;
  final String agency;
  final String holderName;
  final String holderDocument;
  final AccountType type;
  final AccountStatus status;
  final DateTime openingDate;
  
  const Account({
    required this.id,
    required this.number,
    required this.agency,
    required this.holderName,
    required this.holderDocument,
    required this.type,
    required this.status,
    required this.openingDate,
  });
  
  @override
  List<Object?> get props => [
    id,
    number,
    agency,
    holderName,
    holderDocument,
    type,
    status,
    openingDate,
  ];
  
  
  Account copyWith({
    String? id,
    String? number,
    String? agency,
    String? holderName,
    String? holderDocument,
    AccountType? type,
    AccountStatus? status,
    DateTime? openingDate,
  }) {
    return Account(
      id: id ?? this.id,
      number: number ?? this.number,
      agency: agency ?? this.agency,
      holderName: holderName ?? this.holderName,
      holderDocument: holderDocument ?? this.holderDocument,
      type: type ?? this.type,
      status: status ?? this.status,
      openingDate: openingDate ?? this.openingDate,
    );
  }
  
  
  String get formattedNumber => '$agency / $number';
  
  
  bool get isActive => status == AccountStatus.active;
}


enum AccountType {
  checking,
  savings,
  salary,
  investment,
}


enum AccountStatus {
  active,
  inactive,
  blocked,
  closed,
}
