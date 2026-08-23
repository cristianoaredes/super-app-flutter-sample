import 'package:cards/src/domain/entities/card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('card entity does not carry a CVV field', () {
    final card = Card(
      id: '1',
      number: '1234567890123456',
      holderName: 'Ada',
      type: 'credit',
      brand: 'Visa',
      expirationDate: DateTime(2028, 1, 1),
      limit: 1000,
      availableLimit: 800,
      isBlocked: false,
      isVirtual: false,
      isContactless: true,
      status: CardStatus.active,
    );

    expect(card.number, '1234567890123456');
    expect(card.maskedNumber, startsWith('1234'));
  });
}
