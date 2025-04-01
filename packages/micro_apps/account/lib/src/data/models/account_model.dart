import '../../domain/entities/account.dart';


class AccountModel extends Account {
  const AccountModel({
    required super.id,
    required super.number,
    required super.agency,
    required super.holderName,
    required super.holderDocument,
    required super.type,
    required super.status,
    required super.openingDate,
  });
  
  
  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String,
      number: json['number'] as String,
      agency: json['agency'] as String,
      holderName: json['holder_name'] as String,
      holderDocument: json['holder_document'] as String,
      type: _parseAccountType(json['type'] as String),
      status: _parseAccountStatus(json['status'] as String),
      openingDate: DateTime.parse(json['opening_date'] as String),
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'agency': agency,
      'holder_name': holderName,
      'holder_document': holderDocument,
      'type': _accountTypeToString(type),
      'status': _accountStatusToString(status),
      'opening_date': openingDate.toIso8601String(),
    };
  }
  
  
  @override
  AccountModel copyWith({
    String? id,
    String? number,
    String? agency,
    String? holderName,
    String? holderDocument,
    AccountType? type,
    AccountStatus? status,
    DateTime? openingDate,
  }) {
    return AccountModel(
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
  
  
  static AccountType _parseAccountType(String type) {
    switch (type) {
      case 'checking':
        return AccountType.checking;
      case 'savings':
        return AccountType.savings;
      case 'salary':
        return AccountType.salary;
      case 'investment':
        return AccountType.investment;
      default:
        return AccountType.checking;
    }
  }
  
  
  static String _accountTypeToString(AccountType type) {
    switch (type) {
      case AccountType.checking:
        return 'checking';
      case AccountType.savings:
        return 'savings';
      case AccountType.salary:
        return 'salary';
      case AccountType.investment:
        return 'investment';
    }
  }
  
  
  static AccountStatus _parseAccountStatus(String status) {
    switch (status) {
      case 'active':
        return AccountStatus.active;
      case 'inactive':
        return AccountStatus.inactive;
      case 'blocked':
        return AccountStatus.blocked;
      case 'closed':
        return AccountStatus.closed;
      default:
        return AccountStatus.active;
    }
  }
  
  
  static String _accountStatusToString(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return 'active';
      case AccountStatus.inactive:
        return 'inactive';
      case AccountStatus.blocked:
        return 'blocked';
      case AccountStatus.closed:
        return 'closed';
    }
  }
}
