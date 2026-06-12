import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/money/money.dart';
import '../../core/utils/color_hex.dart';
import '../../domain/dashboard/dashboard_summary.dart';
import '../../providers/data_providers.dart';
import '../transactions/transaction_tile.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final recent =
        ref.watch(transactionListProvider(null)).value ?? const [];
    final categories = ref.watch(allCategoriesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Pocket Ledger')),
      body: summary == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TotalBalanceCard(summary: summary),
                const SizedBox(height: 12),
                _StatGrid(summary: summary),
                if (summary.owedToMeMinor != 0 || summary.iOweMinor != 0) ...[
                  const SizedBox(height: 12),
                  _DebtCard(summary: summary),
                ],
                const SizedBox(height: 12),
                _BalanceChartCard(summary: summary),
                if (summary.categorySpending.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SpendingPieCard(summary: summary, categories: categories),
                ],
                const SizedBox(height: 16),
                if (recent.isNotEmpty) ...[
                  Text('Recent transactions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  for (final item in recent.take(10))
                    TransactionTile(item: item),
                ],
                const SizedBox(height: 80), // keep clear of the FAB
              ],
            ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total balance',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              formatMinor(summary.totalBalanceMinor),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final net = summary.monthNetMinor;
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _StatCard(
              label: 'Spent today',
              value: formatMinor(summary.todayExpenseMinor),
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Net this month',
              value:
                  '${net < 0 ? '-' : '+'}${formatMinor(net.abs())}',
              color: net < 0
                  ? Theme.of(context).colorScheme.error
                  : Colors.green.shade700,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _StatCard(
              label: 'Income this month',
              value: formatMinor(summary.monthIncomeMinor),
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Spent this month',
              value: formatMinor(summary.monthExpenseMinor),
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ]),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Owed to you',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    formatMinor(summary.owedToMeMinor),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You owe',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    formatMinor(summary.iOweMinor),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceChartCard extends StatelessWidget {
  const _BalanceChartCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = summary.dailyBalances;
    final spots = [
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].balanceMinor / 100),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance — last 30 days',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touched) => [
                        for (final spot in touched)
                          LineTooltipItem(
                            '${DateFormat('d MMM').format(days[spot.x.toInt()].day)}\n'
                            '${formatMinor(days[spot.x.toInt()].balanceMinor)}',
                            TextStyle(color: colorScheme.onInverseSurface),
                          ),
                      ],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 7,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('d MMM').format(days[i].day),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: colorScheme.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingPieCard extends StatelessWidget {
  const _SpendingPieCard({required this.summary, required this.categories});

  final DashboardSummary summary;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final c in categories) c.id: c};
    final top = summary.categorySpending.take(8).toList();
    final total = top.fold<int>(0, (s, c) => s + c.amountMinor);
    if (total == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending — last 30 days',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  height: 140,
                  width: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        for (final spend in top)
                          PieChartSectionData(
                            value: spend.amountMinor.toDouble(),
                            color: colorFromHex(
                                byId[spend.categoryId]?.color),
                            showTitle: false,
                            radius: 36,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final spend in top)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorFromHex(
                                      byId[spend.categoryId]?.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  byId[spend.categoryId]?.name ??
                                      'Uncategorised',
                                  style:
                                      Theme.of(context).textTheme.labelSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(spend.amountMinor * 100 / total).round()}%',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
