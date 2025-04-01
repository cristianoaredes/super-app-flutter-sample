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
        final titleFontSize = availableWidth * 0.045;
        final tabFontSize = availableWidth * 0.035;
        final padding = availableWidth * 0.04;

        return Card(
          elevation: 3.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(availableWidth * 0.025),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Summary',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: padding * 0.8),
                Theme(
                  data: Theme.of(context).copyWith(
                    tabBarTheme: TabBarTheme(
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
                SizedBox(height: padding * 0.8),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.40,
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

    final translatedCategories = categories.map((category) {
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
    }).toList();

    final screenSize = MediaQuery.of(context).size;
    final availableWidth = screenSize.width;

    final chartSize = availableWidth * 0.60;
    final fontSize = availableWidth * 0.035;

    return Column(
      children: [
        SizedBox(height: availableWidth * 0.10),
        Container(
          height: chartSize,
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: 1.0,
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
                      radius: chartSize * 0.45,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      titlePositionPercentageOffset: 0.6,
                    );
                  },
                ),
                sectionsSpace: 3.0,
                centerSpaceRadius: chartSize * 0.15,
                startDegreeOffset: -90.0,
                centerSpaceColor: Theme.of(context).cardColor,
              ),
            ),
          ),
        ),
        SizedBox(height: availableWidth * 0.08),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: availableWidth * 0.03,
          runSpacing: availableWidth * 0.03,
          children: List.generate(
            categories.length,
            (index) {
              final category = translatedCategories[index];
              final color = colors[index % colors.length];

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: availableWidth * 0.025,
                    height: availableWidth * 0.025,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: availableWidth * 0.01),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: availableWidth * 0.03,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
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

    final screenSize = MediaQuery.of(context).size;
    final availableWidth = screenSize.width;
    final availableHeight = screenSize.height * 0.3;

    final fontSize = availableWidth * 0.03;
    final barWidth = availableWidth * 0.06;

    return Container(
      height: availableHeight,
      padding: EdgeInsets.symmetric(
        vertical: availableWidth * 0.03,
        horizontal: availableWidth * 0.02,
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.shade700,
              tooltipPadding: EdgeInsets.all(availableWidth * 0.02),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final expense = widget.monthlyExpenses[groupIndex];
                return BarTooltipItem(
                  'R\$ ${expense.amount.toStringAsFixed(2)}',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize * 0.9,
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
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < widget.monthlyExpenses.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10.0),
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
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: Text(
                      'R\$ ${value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                reservedSize: 50.0,
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
  }
}
