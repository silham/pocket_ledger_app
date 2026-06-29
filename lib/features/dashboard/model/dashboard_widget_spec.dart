import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/dashboard_tiles.dart';
import 'dashboard_widget_type.dart';

/// Builds the live widget for a placed [WidgetInstance].
typedef TileBuilder = Widget Function(
    BuildContext context, WidgetRef ref, WidgetInstance instance);

/// Static metadata for one widget type: how it shows in the catalog, what
/// sizes it allows, and how it renders. The single source of truth shared by
/// the grid, the resize control, and the add-widget sheet.
class DashboardWidgetSpec {
  const DashboardWidgetSpec({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.allowedSizes,
    required this.builder,
    this.needsConfig = false,
  });

  final DashboardWidgetType type;
  final String title;
  final String description;
  final IconData icon;

  /// First entry is the default size used when the widget is added.
  final List<GridSize> allowedSizes;
  final TileBuilder builder;

  /// When true, tapping the tile in edit mode opens a config picker
  /// (e.g. choosing the account for [DashboardWidgetType.accountBalance]).
  final bool needsConfig;

  GridSize get defaultSize => allowedSizes.first;
}

/// The catalog of every available dashboard widget.
final Map<DashboardWidgetType, DashboardWidgetSpec> kDashboardCatalog = {
  DashboardWidgetType.totalBalance: DashboardWidgetSpec(
    type: DashboardWidgetType.totalBalance,
    title: 'Total balance',
    description: 'Sum of all account balances',
    icon: Icons.account_balance_wallet_outlined,
    allowedSizes: const [GridSize(4, 2), GridSize(2, 2), GridSize(2, 1)],
    builder: (context, ref, _) => const TotalBalanceTile(),
  ),
  DashboardWidgetType.statSpentToday: DashboardWidgetSpec(
    type: DashboardWidgetType.statSpentToday,
    title: 'Spent today',
    description: "Today's total expenses",
    icon: Icons.today_outlined,
    allowedSizes: const [GridSize(2, 1), GridSize(4, 1), GridSize(2, 2)],
    builder: (context, ref, _) =>
        const StatTile(type: DashboardWidgetType.statSpentToday),
  ),
  DashboardWidgetType.statNet30: DashboardWidgetSpec(
    type: DashboardWidgetType.statNet30,
    title: 'Net — past 30 days',
    description: 'Income minus spending, last 30 days',
    icon: Icons.swap_vert,
    allowedSizes: const [GridSize(2, 1), GridSize(4, 1), GridSize(2, 2)],
    builder: (context, ref, _) =>
        const StatTile(type: DashboardWidgetType.statNet30),
  ),
  DashboardWidgetType.statIncome30: DashboardWidgetSpec(
    type: DashboardWidgetType.statIncome30,
    title: 'Income — past 30 days',
    description: 'Income received, last 30 days',
    icon: Icons.arrow_downward,
    allowedSizes: const [GridSize(2, 1), GridSize(4, 1), GridSize(2, 2)],
    builder: (context, ref, _) =>
        const StatTile(type: DashboardWidgetType.statIncome30),
  ),
  DashboardWidgetType.statSpent30: DashboardWidgetSpec(
    type: DashboardWidgetType.statSpent30,
    title: 'Spent — past 30 days',
    description: 'Expenses, last 30 days',
    icon: Icons.arrow_upward,
    allowedSizes: const [GridSize(2, 1), GridSize(4, 1), GridSize(2, 2)],
    builder: (context, ref, _) =>
        const StatTile(type: DashboardWidgetType.statSpent30),
  ),
  DashboardWidgetType.debt: DashboardWidgetSpec(
    type: DashboardWidgetType.debt,
    title: 'Owed / You owe',
    description: 'What people owe you and what you owe',
    icon: Icons.handshake_outlined,
    allowedSizes: const [GridSize(4, 1), GridSize(2, 1), GridSize(4, 2)],
    builder: (context, ref, _) => const DebtTile(),
  ),
  DashboardWidgetType.balanceChart: DashboardWidgetSpec(
    type: DashboardWidgetType.balanceChart,
    title: 'Balance — last 30 days',
    description: 'Line chart of total balance over time',
    icon: Icons.show_chart,
    allowedSizes: const [GridSize(4, 4), GridSize(4, 3), GridSize(2, 3)],
    builder: (context, ref, _) => const BalanceChartTile(),
  ),
  DashboardWidgetType.spendingPie: DashboardWidgetSpec(
    type: DashboardWidgetType.spendingPie,
    title: 'Spending by category',
    description: 'Pie of expenses by category, last 30 days',
    icon: Icons.pie_chart_outline,
    allowedSizes: const [GridSize(4, 3), GridSize(4, 4), GridSize(4, 2)],
    builder: (context, ref, _) => const SpendingPieTile(),
  ),
  DashboardWidgetType.spendingByDay: DashboardWidgetSpec(
    type: DashboardWidgetType.spendingByDay,
    title: 'Spending by day',
    description: 'Bar chart of daily expenses, last 30 days',
    icon: Icons.bar_chart,
    allowedSizes: const [GridSize(4, 3), GridSize(4, 4), GridSize(4, 2)],
    builder: (context, ref, _) => const SpendingByDayTile(),
  ),
  DashboardWidgetType.accountBalance: DashboardWidgetSpec(
    type: DashboardWidgetType.accountBalance,
    title: 'Balance of an account',
    description: 'Current balance of a chosen account',
    icon: Icons.account_balance_outlined,
    allowedSizes: const [GridSize(2, 1), GridSize(4, 1), GridSize(2, 2)],
    needsConfig: true,
    builder: (context, ref, instance) =>
        AccountBalanceTile(config: instance.config),
  ),
  DashboardWidgetType.recentTransactions: DashboardWidgetSpec(
    type: DashboardWidgetType.recentTransactions,
    title: 'Recent transactions',
    description: 'Your latest transactions',
    icon: Icons.receipt_long_outlined,
    allowedSizes: const [GridSize(4, 4), GridSize(4, 6), GridSize(4, 3)],
    builder: (context, ref, instance) =>
        RecentTransactionsTile(config: instance.config),
  ),
};
