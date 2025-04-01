import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/account_summary_card.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/transaction_chart.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardBloc _dashboardBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    try {
      _dashboardBloc = BlocProvider.of<DashboardBloc>(context);
    } catch (e) {
      _dashboardBloc = GetIt.instance<DashboardBloc>();
    }

    
    _dashboardBloc.add(const LoadDashboardEvent());
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    
    super.dispose();
  }

  void _refreshDashboard() {
    _dashboardBloc.add(const RefreshDashboardEvent());
  }

  @override
  Widget build(BuildContext context) {
    
    return BlocProvider.value(
      value: _dashboardBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshDashboard,
            ),
          ],
        ),
        body: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardInitialState ||
                state is DashboardLoadingState) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is DashboardLoadingWithDataState) {
              return _buildDashboardWithData(
                context,
                state.accountSummary,
                state.transactionSummary,
                state.quickActions,
                isLoading: true,
              );
            }

            if (state is DashboardLoadedState) {
              return _buildDashboardWithData(
                context,
                state.accountSummary,
                state.transactionSummary,
                state.quickActions,
              );
            }

            if (state is DashboardErrorState) {
              if (state.accountSummary != null ||
                  state.transactionSummary != null ||
                  state.quickActions != null) {
                return _buildDashboardWithData(
                  context,
                  state.accountSummary,
                  state.transactionSummary,
                  state.quickActions,
                  errorMessage: state.message,
                );
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar o dashboard',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshDashboard,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildDashboardWithData(
    BuildContext context,
    final accountSummary,
    final transactionSummary,
    final quickActions, {
    bool isLoading = false,
    String? errorMessage,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshDashboard();
        
        await Future.delayed(const Duration(seconds: 1));
      },
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        onPressed: _refreshDashboard,
                      ),
                    ],
                  ),
                ),
              if (accountSummary != null)
                AccountSummaryCard(accountSummary: accountSummary),
              if (accountSummary == null) const _PlaceholderCard(height: 180.0),
              const SizedBox(height: 16.0),
              if (quickActions != null)
                QuickActionsGrid(quickActions: quickActions),
              if (quickActions == null) const _PlaceholderCard(height: 120.0),
              const SizedBox(height: 16.0),
              if (transactionSummary != null) ...[
                TransactionChart(
                  categoryDistribution: transactionSummary.categoryDistribution,
                  monthlyExpenses: transactionSummary.monthlyExpenses,
                ),
                const SizedBox(height: 16.0),
                const Text(
                  'Transações Recentes',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                RecentTransactionsList(
                  transactions: transactionSummary.recentTransactions,
                ),
              ],
              if (transactionSummary == null) ...[
                const _PlaceholderCard(height: 200.0),
                const SizedBox(height: 16.0),
                const _PlaceholderCard(height: 300.0),
              ],
              const SizedBox(height: 16.0),
            ],
          ),
          if (isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}


class _PlaceholderCard extends StatelessWidget {
  final double height;

  const _PlaceholderCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8.0),
      ),
    );
  }
}
