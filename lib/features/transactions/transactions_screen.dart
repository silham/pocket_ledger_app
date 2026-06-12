import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/money/money.dart';
import '../../data/transactions_repository.dart';
import '../../domain/models/enums.dart';
import '../../providers/data_providers.dart';
import 'transaction_tile.dart';

// ─── How many months to expose in the tab bar ────────────────────────────────
// 12 past months + current month + 2 future months
const _kPastMonths = 12;
const _kFutureMonths = 2;
const _kMonthCount = _kPastMonths + 1 + _kFutureMonths;
const _kInitialIndex = _kPastMonths; // current month tab index

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with TickerProviderStateMixin {
  late final List<DateTime> _months;
  late final TabController _tabController;
  TransactionType? _typeFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Generate months: Dart's DateTime constructor normalises overflow/underflow.
    _months = List.generate(
      _kMonthCount,
      (i) => DateTime(now.year, now.month - _kPastMonths + i),
    );
    _tabController = TabController(
      length: _kMonthCount,
      initialIndex: _kInitialIndex,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Only rebuild once the animation settles — avoids rapid provider switches.
    if (!_tabController.indexIsChanging) setState(() {});
  }

  DateTime get _selectedMonth => _months[_tabController.index];

  @override
  Widget build(BuildContext context) {
    final m = _selectedMonth;

    // Full-month stream (all types) — drives the summary bar.
    final allAsync = ref.watch(
      transactionsByMonthProvider(
          (type: null, year: m.year, month: m.month)),
    );
    // Optionally filtered stream — drives the list.
    final listAsync = _typeFilter == null
        ? allAsync
        : ref.watch(
            transactionsByMonthProvider(
                (type: _typeFilter, year: m.year, month: m.month)),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: _MonthTabBar(controller: _tabController, months: _months),
      ),
      body: Column(
        children: [
          _SummaryBar(allAsync: allAsync),
          _TypeFilterRow(
            selected: _typeFilter,
            onChanged: (t) => setState(() => _typeFilter = t),
          ),
          Expanded(
            child: listAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load: $e')),
              data: (list) => list.isEmpty
                  ? const _EmptyState()
                  : _GroupedTransactionList(items: list),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month tab bar ────────────────────────────────────────────────────────────

class _MonthTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _MonthTabBar({required this.controller, required this.months});

  final TabController controller;
  final List<DateTime> months;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerHeight: 0,
      tabs: [
        for (final m in months)
          Tab(
            text: m.year == now.year
                ? DateFormat('MMM').format(m)
                : DateFormat("MMM ''yy").format(m),
          ),
      ],
    );
  }
}

// ─── Summary bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.allAsync});

  final AsyncValue<List<TransactionListItem>> allAsync;

  @override
  Widget build(BuildContext context) {
    final list = allAsync.value ?? const [];
    var expense = 0;
    var income = 0;
    for (final item in list) {
      final t = item.transaction;
      if (t.type == TransactionType.expense) expense += t.amountMinor;
      if (t.type == TransactionType.income) income += t.amountMinor;
    }
    final net = income - expense;
    final colorScheme = Theme.of(context).colorScheme;
    final errColor = colorScheme.error;
    final incColor = Colors.green.shade700;

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _SumCell(
            icon: Icons.arrow_downward_rounded,
            value: formatMinor(expense),
            color: errColor,
          ),
          const Spacer(),
          _SumCell(
            icon: Icons.arrow_upward_rounded,
            value: formatMinor(income),
            color: incColor,
          ),
          const Spacer(),
          _SumCell(
            prefix: '= ',
            value: '${net < 0 ? '-' : '+'}${formatMinor(net.abs())}',
            color: net < 0 ? errColor : incColor,
          ),
        ],
      ),
    );
  }
}

class _SumCell extends StatelessWidget {
  const _SumCell({
    this.icon,
    this.prefix,
    required this.value,
    required this.color,
  });

  final IconData? icon;
  final String? prefix;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        if (prefix != null)
          Text(prefix!,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─── Type filter chips ────────────────────────────────────────────────────────

class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({required this.selected, required this.onChanged});

  final TransactionType? selected;
  final ValueChanged<TransactionType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final type in TransactionType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(type.label),
                selected: selected == type,
                onSelected: (_) =>
                    onChanged(selected == type ? null : type),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Grouped transaction list ─────────────────────────────────────────────────

class _GroupedTransactionList extends ConsumerWidget {
  const _GroupedTransactionList({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group into ordered day buckets (items are already newest-first).
    final days = <DateTime>[];
    final byDay = <DateTime, List<TransactionListItem>>{};
    for (final item in items) {
      final local = item.transaction.date.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (!byDay.containsKey(day)) {
        days.add(day);
        byDay[day] = [];
      }
      byDay[day]!.add(item);
    }

    return ListView(
      children: [
        for (final day in days) ...[
          _DayHeader(day: day),
          for (final item in byDay[day]!) _DismissibleTile(item: item),
          _DayFooter(items: byDay[day]!),
        ],
        const SizedBox(height: 80), // clear the FAB
      ],
    );
  }
}

// ─── Day header ───────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthDay = DateFormat('MMMM d').format(day); // "June 12"
    final label = switch (today.difference(day).inDays) {
      0 => 'Today, $monthDay',
      1 => 'Yesterday, $monthDay',
      _ => DateFormat('EEE, d MMM yyyy').format(day),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ─── Day footer (cash-flow subtotal) ─────────────────────────────────────────

class _DayFooter extends StatelessWidget {
  const _DayFooter({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    var cashFlow = 0;
    for (final item in items) {
      final t = item.transaction;
      if (t.type == TransactionType.expense) cashFlow -= t.amountMinor;
      if (t.type == TransactionType.income) cashFlow += t.amountMinor;
    }
    final count = items.length;
    final flowStr = cashFlow == 0
        ? formatMinor(0)
        : '${cashFlow < 0 ? '-' : '+'}${formatMinor(cashFlow.abs())}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Text(
        'Total cash flow: $flowStr  •  '
        '$count transaction${count == 1 ? '' : 's'}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ─── Dismissible tile (delete) ────────────────────────────────────────────────

class _DismissibleTile extends ConsumerWidget {
  const _DismissibleTile({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = item.transaction;
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child:
            Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        await ref.read(ledgerServiceProvider).deleteTransaction(t.id);
        HapticFeedback.mediumImpact();
        showAppSnackBar('${t.type.label} deleted');
      },
      child: TransactionTile(item: item),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
            'Account balances will be restored as if it never happened.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions this month',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add one',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
