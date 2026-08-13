import 'package:dashboard/src/domain/entities/account_summary.dart';
import 'package:dashboard/src/domain/entities/quick_action.dart';
import 'package:dashboard/src/presentation/widgets/account_summary_card.dart';
import 'package:dashboard/src/presentation/widgets/quick_actions_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    required Size size,
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final summary = AccountSummary(
    accountId: 'acc-1',
    accountNumber: '12345-6',
    agency: '0001',
    balance: 12345.67,
    income: 5000,
    expenses: 3500,
    savings: 1000,
    investments: 2000,
    lastUpdate: DateTime(2026, 1, 1),
  );

  final actions = const [
    QuickAction(
      id: 'pix',
      title: 'Pix',
      description: 'Pix',
      icon: Icons.bolt,
      route: '/pix',
    ),
    QuickAction(
      id: 'transfer',
      title: 'Transferência',
      description: 'Transfer',
      icon: Icons.swap_horiz,
      route: '/account/transfer',
    ),
    QuickAction(
      id: 'pay',
      title: 'Pagamentos',
      description: 'Pay',
      icon: Icons.payment,
      route: '/payments',
    ),
    QuickAction(
      id: 'cards',
      title: 'Cartões',
      description: 'Cards',
      icon: Icons.credit_card,
      route: '/cards',
    ),
  ];

  testWidgets('account summary does not overflow at 320px', (tester) async {
    await pumpAt(
      tester,
      AccountSummaryCard(accountSummary: summary),
      size: const Size(320, 640),
    );
    expect(find.text('Saldo Disponível'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account summary does not overflow at 1400px', (tester) async {
    await pumpAt(
      tester,
      AccountSummaryCard(accountSummary: summary),
      size: const Size(1400, 800),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick actions grid does not overflow at 320px', (tester) async {
    await pumpAt(
      tester,
      QuickActionsGrid(quickActions: actions),
      size: const Size(320, 640),
    );
    expect(find.text('Ações Rápidas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
