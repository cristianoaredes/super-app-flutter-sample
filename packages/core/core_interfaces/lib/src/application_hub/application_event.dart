
abstract class ApplicationEvent {
  
  String get eventType;
  
  
  Map<String, dynamic> toMap();
  
  
  ApplicationEvent copyWith({Map<String, dynamic>? data});
}


class UserLoggedInEvent extends ApplicationEvent {
  final String userId;
  final String username;
  final Map<String, dynamic> userData;
  
  UserLoggedInEvent({
    required this.userId,
    required this.username,
    this.userData = const {},
  });
  
  @override
  String get eventType => 'user_logged_in';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userData': userData,
    };
  }
  
  @override
  ApplicationEvent copyWith({Map<String, dynamic>? data}) {
    if (data == null) return this;
    
    return UserLoggedInEvent(
      userId: data['userId'] ?? this.userId,
      username: data['username'] ?? this.username,
      userData: data['userData'] ?? this.userData,
    );
  }
}


class UserLoggedOutEvent extends ApplicationEvent {
  final String userId;
  
  UserLoggedOutEvent({
    required this.userId,
  });
  
  @override
  String get eventType => 'user_logged_out';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
    };
  }
  
  @override
  ApplicationEvent copyWith({Map<String, dynamic>? data}) {
    if (data == null) return this;
    
    return UserLoggedOutEvent(
      userId: data['userId'] ?? this.userId,
    );
  }
}


class TransactionCompletedEvent extends ApplicationEvent {
  final String transactionId;
  final double amount;
  final String type;
  final Map<String, dynamic> transactionData;
  
  TransactionCompletedEvent({
    required this.transactionId,
    required this.amount,
    required this.type,
    this.transactionData = const {},
  });
  
  @override
  String get eventType => 'transaction_completed';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'amount': amount,
      'type': type,
      'transactionData': transactionData,
    };
  }
  
  @override
  ApplicationEvent copyWith({Map<String, dynamic>? data}) {
    if (data == null) return this;
    
    return TransactionCompletedEvent(
      transactionId: data['transactionId'] ?? this.transactionId,
      amount: data['amount'] ?? this.amount,
      type: data['type'] ?? this.type,
      transactionData: data['transactionData'] ?? this.transactionData,
    );
  }
}


class AccountBalanceChangedEvent extends ApplicationEvent {
  final String accountId;
  final double newBalance;
  final double previousBalance;
  
  AccountBalanceChangedEvent({
    required this.accountId,
    required this.newBalance,
    required this.previousBalance,
  });
  
  @override
  String get eventType => 'account_balance_changed';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'newBalance': newBalance,
      'previousBalance': previousBalance,
    };
  }
  
  @override
  ApplicationEvent copyWith({Map<String, dynamic>? data}) {
    if (data == null) return this;
    
    return AccountBalanceChangedEvent(
      accountId: data['accountId'] ?? this.accountId,
      newBalance: data['newBalance'] ?? this.newBalance,
      previousBalance: data['previousBalance'] ?? this.previousBalance,
    );
  }
}


class CardAddedEvent extends ApplicationEvent {
  final String cardId;
  final String cardType;
  final String lastFourDigits;
  
  CardAddedEvent({
    required this.cardId,
    required this.cardType,
    required this.lastFourDigits,
  });
  
  @override
  String get eventType => 'card_added';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'cardType': cardType,
      'lastFourDigits': lastFourDigits,
    };
  }
  
  @override
  ApplicationEvent copyWith({Map<String, dynamic>? data}) {
    if (data == null) return this;
    
    return CardAddedEvent(
      cardId: data['cardId'] ?? this.cardId,
      cardType: data['cardType'] ?? this.cardType,
      lastFourDigits: data['lastFourDigits'] ?? this.lastFourDigits,
    );
  }
}


class PixKeyRegisteredEvent extends ApplicationEvent {
  final String keyType;
  final String keyValue;
  
  PixKeyRegisteredEvent({
    required this.keyType,
    required this.keyValue,
  });
  
  @override
  String get eventType => 'pix_key_registered';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'keyType': keyType,
      'keyValue': keyValue,
    };
  }
  
  @override
  ApplicationEvent copyWith({Map<String, dynamic>? data}) {
    if (data == null) return this;
    
    return PixKeyRegisteredEvent(
      keyType: data['keyType'] ?? this.keyType,
      keyValue: data['keyValue'] ?? this.keyValue,
    );
  }
}
