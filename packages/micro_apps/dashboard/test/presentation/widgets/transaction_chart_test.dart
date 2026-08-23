import 'package:dashboard/src/domain/entities/transaction_summary.dart';
import 'package:dashboard/src/presentation/widgets/transaction_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final categories = <String, double>{
    'food': 1200,
    'housing': 2500,
    'transportation': 400,
    'entertainment': 300,
    'health': 150,
    'shopping': 800,
  };

  final months = const [
    MonthlyExpense(month: 'Jan', amount: 2100),
    MonthlyExpense(month: 'Fev', amount: 1800),
    MonthlyExpense(month: 'Mar', amount: 2400),
    MonthlyExpense(month: 'Abr', amount: 1600),
  ];

  Future<void> pumpChart(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TransactionChart(
                categoryDistribution: categories,
                monthlyExpenses: months,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('does not overflow the pie chart on a wide desktop canvas',
      (tester) async {
    await pumpChart(tester, size: const Size(1400, 800));

    expect(find.byType(TransactionChart), findsOneWidget);
    expect(find.text('Financial Summary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow the pie chart on a narrow phone canvas',
      (tester) async {
    await pumpChart(tester, size: const Size(320, 640));

    expect(find.byType(TransactionChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow the monthly bar chart on a wide canvas',
      (tester) async {
    await pumpChart(tester, size: const Size(1400, 800));

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    expect(find.text('Jan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
