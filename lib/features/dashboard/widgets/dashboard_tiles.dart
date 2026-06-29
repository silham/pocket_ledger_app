import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/utils/color_hex.dart';
import '../../../providers/data_providers.dart';
import '../../dashboard/dashboard_providers.dart';
import '../../transactions/transaction_tile.dart';
import '../model/dashboard_widget_type.dart';
import 'tile_card.dart';

/// Shows a centered spinner inside a tile while the summary is still loading.
class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder();

  @override
  Widget build(BuildContext context) => const TileCard(
        child: Center(child: SizedBox.shrink()),
      );
}

/// A short "label + big value" stat. Reused by all four stat widget types.
class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: textTheme.labelMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.titleLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TotalBalanceTile extends ConsumerWidget {
  const TotalBalanceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    if (summary == null) return const _TilePlaceholder();
    final colorScheme = Theme.of(context).colorScheme;
    return TileCard(
      color: colorScheme.primaryContainer,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Total balance',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: colorScheme.onPrimaryContainer)),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMinor(summary.totalBalanceMinor),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the four 30-day stat cards, selected by [type].
class StatTile extends ConsumerWidget {
  const StatTile({super.key, required this.type});

  final DashboardWidgetType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    if (summary == null) return const _TilePlaceholder();
    final scheme = Theme.of(context).colorScheme;
    final green = Colors.green.shade700;

    switch (type) {
      case DashboardWidgetType.statSpentToday:
        return _ValueTile(
          label: 'Spent today',
          value: formatMinor(summary.todayExpenseMinor),
          color: scheme.error,
        );
      case DashboardWidgetType.statNet30:
        final net = summary.last30NetMinor;
        return _ValueTile(
          label: 'Net — past 30 days',
          value: '${net < 0 ? '-' : '+'}${formatMinor(net.abs())}',
          color: net < 0 ? scheme.error : green,
        );
      case DashboardWidgetType.statIncome30:
        return _ValueTile(
          label: 'Income — past 30 days',
          value: formatMinor(summary.last30IncomeMinor),
          color: green,
        );
      case DashboardWidgetType.statSpent30:
        return _ValueTile(
          label: 'Spent — past 30 days',
          value: formatMinor(summary.last30ExpenseMinor),
          color: scheme.error,
        );
      default:
        return const _TilePlaceholder();
    }
  }
}

class DebtTile extends ConsumerWidget {
  const DebtTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    if (summary == null) return const _TilePlaceholder();
    final textTheme = Theme.of(context).textTheme;

    Widget column(String label, int amount, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: textTheme.labelMedium),
            const SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatMinor(amount),
                    style: textTheme.titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        );

    return TileCard(
      child: Row(
        children: [
          Expanded(
              child: column('Owed to you', summary.owedToMeMinor,
                  Colors.green.shade700)),
          Expanded(
              child: column('You owe', summary.iOweMinor,
                  Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }
}

class BalanceChartTile extends ConsumerWidget {
  const BalanceChartTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    if (summary == null) return const _TilePlaceholder();
    final colorScheme = Theme.of(context).colorScheme;
    final days = summary.dailyBalances;
    final spots = [
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].balanceMinor / 100),
    ];

    return TileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TileTitle('Balance — last 30 days'),
          const SizedBox(height: 16),
          Expanded(
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
                        if (i < 0 || i >= days.length || i % 7 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(DateFormat('M/d').format(days[i].day),
                              style: Theme.of(context).textTheme.labelSmall),
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
    );
  }
}

class SpendingByDayTile extends ConsumerWidget {
  const SpendingByDayTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    if (summary == null) return const _TilePlaceholder();
    final colorScheme = Theme.of(context).colorScheme;
    final days = summary.dailyExpenses;
    final maxY = days.fold<int>(0, (m, d) => d.amountMinor > m ? d.amountMinor : m);

    return TileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TileTitle('Spending by day — last 30 days'),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: maxY == 0 ? 1 : maxY / 100,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${DateFormat('d MMM').format(days[group.x].day)}\n'
                      '${formatMinor(days[group.x].amountMinor)}',
                      TextStyle(color: colorScheme.onInverseSurface),
                    ),
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
                        if (i < 0 || i >= days.length || i % 7 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(DateFormat('M/d').format(days[i].day),
                              style: Theme.of(context).textTheme.labelSmall),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: days[i].amountMinor / 100,
                        color: colorScheme.primary,
                        width: 4,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2)),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpendingPieTile extends ConsumerWidget {
  const SpendingPieTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    if (summary == null) return const _TilePlaceholder();
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final byId = {for (final c in categories) c.id: c};
    final top = summary.categorySpending.take(8).toList();
    final total = top.fold<int>(0, (s, c) => s + c.amountMinor);

    if (total == 0) {
      return const TileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TileTitle('Spending — last 30 days'),
            SizedBox(height: 16),
            Expanded(
              child: Center(child: Text('No spending in the last 30 days')),
            ),
          ],
        ),
      );
    }

    return TileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TileTitle('Spending — last 30 days'),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        for (final spend in top)
                          PieChartSectionData(
                            value: spend.amountMinor.toDouble(),
                            color: colorFromHex(byId[spend.categoryId]?.color),
                            showTitle: false,
                            radius: 36,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
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
          ),
        ],
      ),
    );
  }
}

/// Balance of a single chosen account. [config] carries `{'accountId': ...}`.
class AccountBalanceTile extends ConsumerWidget {
  const AccountBalanceTile({super.key, required this.config});

  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider).value;
    final accountId = config['accountId'] as String?;
    final textTheme = Theme.of(context).textTheme;

    if (accounts == null) return const _TilePlaceholder();

    final matches = accounts.where((a) => a.id == accountId);
    final account = matches.isEmpty ? null : matches.first;
    if (account == null) {
      return TileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Account balance', style: textTheme.labelMedium),
            const SizedBox(height: 4),
            Text('Tap to pick an account',
                style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }

    return _ValueTile(
      label: account.name,
      value: formatMinor(account.balanceMinor),
    );
  }
}

/// Compact list of the most recent transactions. [config] carries
/// `{'count': N}` (defaults to 5).
class RecentTransactionsTile extends ConsumerWidget {
  const RecentTransactionsTile({super.key, required this.config});

  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(transactionListProvider(null)).value ?? const [];
    final count = (config['count'] as num?)?.toInt() ?? 5;
    final items = recent.take(count).toList();

    return TileCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TileTitle('Recent transactions'),
          const SizedBox(height: 4),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Text('No transactions yet',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final item in items)
                    TransactionTile(item: item),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
