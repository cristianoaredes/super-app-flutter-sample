import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/transaction_summary.dart';

class TransactionChart extends StatefulWidget {
  final Map<String, double> categoryDistribution;
  final List<MonthlyExpense> monthlyExpenses;

  const TransactionChart({
    super.key,
    required this.categoryDistribution,
    required this.monthlyExpenses,
  });

  @override
  State<TransactionChart> createState() => _TransactionChartState();
}

class _TransactionChartState extends State<TransactionChart>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _chartViewportHeight = 260.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final titleFontSize = (availableWidth * 0.045).clamp(16.0, 20.0);
        final tabFontSize = (availableWidth * 0.035).clamp(12.0, 14.0);
        final padding = (availableWidth * 0.04).clamp(12.0, 16.0);

        return Card(
          elevation: 3.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Financial Summary',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: padding * 0.6),
                Theme(
                  data: Theme.of(context).copyWith(
                    tabBarTheme: TabBarThemeData(
                      labelStyle: TextStyle(
                        fontSize: tabFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: tabFontSize,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Categories'),
                      Tab(text: 'Monthly'),
                    ],
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorWeight: 3.0,
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                ),
                SizedBox(height: padding * 0.6),
                SizedBox(
                  height: _chartViewportHeight,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPieChart(),
                      _buildBarChart(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPieChart() {
    if (widget.categoryDistribution.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final categories = widget.categoryDistribution.keys.toList();
    final values = widget.categoryDistribution.values.toList();
    final total = values.fold<double>(0, (sum, value) => sum + value);

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];

    final translatedCategories = categories.map(_translateCategory).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        const legendBudget = 64.0;
        final chartSize = math.min(
          maxW * 0.55,
          math.max(96.0, maxH - legendBudget),
        );
        final fontSize = (chartSize * 0.07).clamp(10.0, 13.0);

        return Column(
          children: [
            SizedBox(
              height: chartSize,
              width: chartSize,
              child: PieChart(
                PieChartData(
                  sections: List.generate(
                    categories.length,
                    (index) {
                      final value = values[index];
                      final percentage = (value / total) * 100;

                      return PieChartSectionData(
                        color: colors[index % colors.length],
                        value: value,
                        title: '${percentage.toStringAsFixed(1)}%',
                        radius: chartSize * 0.38,
                        titleStyle: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        titlePositionPercentageOffset: 0.58,
                      );
                    },
                  ),
                  sectionsSpace: 3.0,
                  centerSpaceRadius: chartSize * 0.14,
                  startDegreeOffset: -90.0,
                  centerSpaceColor: Theme.of(context).cardColor,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12.0,
                  runSpacing: 8.0,
                  children: List.generate(
                    categories.length,
                    (index) {
                      final category = translatedCategories[index];
                      final color = colors[index % colors.length];

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10.0,
                            height: 10.0,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBarChart() {
    if (widget.monthlyExpenses.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final maxY = widget.monthlyExpenses
        .map((expense) => expense.amount)
        .reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final fontSize = (availableWidth * 0.03).clamp(10.0, 12.0);
        final barWidth = (availableWidth * 0.06).clamp(12.0, 22.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 4.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY * 1.2,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey.shade700,
                  tooltipPadding: const EdgeInsets.all(8.0),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final expense = widget.monthlyExpenses[groupIndex];
                    return BarTooltipItem(
                      'R\$ ${expense.amount.toStringAsFixed(2)}',
                      TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28.0,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 &&
                          index < widget.monthlyExpenses.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            widget.monthlyExpenses[index].month,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44.0,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          'R\$ ${value.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxY / 5,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
              ),
              barGroups: List.generate(
                widget.monthlyExpenses.length,
                (index) {
                  final expense = widget.monthlyExpenses[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: expense.amount,
                        color: Theme.of(context).colorScheme.primary,
                        width: barWidth,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6.0),
                          topRight: Radius.circular(6.0),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _translateCategory(String category) {
    switch (category) {
      case 'salary':
        return 'Salário';
      case 'housing':
        return 'Moradia';
      case 'food':
        return 'Alimentação';
      case 'transportation':
        return 'Transporte';
      case 'entertainment':
        return 'Entretenimento';
      case 'health':
        return 'Saúde';
      case 'education':
        return 'Educação';
      case 'shopping':
        return 'Compras';
      case 'utilities':
        return 'Utilidades';
      case 'other':
        return 'Outros';
      default:
        return category;
    }
  }
}
