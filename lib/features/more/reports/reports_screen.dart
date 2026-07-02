import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/app_icons.dart';
import '../../../core/utils/color_hex.dart';
import '../../../domain/reports/report_summary.dart';
import '../../../providers/data_providers.dart';

/// [start] inclusive, [end] exclusive — both local-time day boundaries.
typedef _RangeKey = ({DateTime start, DateTime end});

final _reportProvider =
    Provider.autoDispose.family<ReportSummary?, _RangeKey>((ref, key) {
  final transactions = ref.watch(allActiveTransactionsProvider).value;
  if (transactions == null) return null;
  return ReportSummary.compute(
    transactions: transactions,
    start: key.start,
    end: key.end,
  );
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  // Inclusive day boundaries the user sees; [_end] is made exclusive for the
  // query by adding one day.
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final r = _thisMonth();
    _start = r.$1;
    _end = r.$2;
  }

  @override
  Widget build(BuildContext context) {
    final endExclusive = DateTime(_end.year, _end.month, _end.day + 1);
    final report =
        ref.watch(_reportProvider((start: _start, end: endExclusive)));
    final accounts = ref.watch(activeAccountsProvider).value;
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final byId = {for (final c in categories) c.id: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: report == null || accounts == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _rangeSelector(context),
                const SizedBox(height: 8),
                _MonthSummaryCard(report: report),
                const SizedBox(height: 12),
                if (report.categorySpending.isNotEmpty) ...[
                  _CategoryBars(report: report, byId: byId),
                  const SizedBox(height: 12),
                ],
                _AccountBalancesCard(accounts: accounts),
                if (report.owedToMeMinor != 0 || report.iOweMinor != 0) ...[
                  const SizedBox(height: 12),
                  _DebtSummaryCard(report: report),
                ],
              ],
            ),
    );
  }

  Widget _rangeSelector(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final label = _start == _end
        ? fmt.format(_start)
        : '${fmt.format(_start)} – ${fmt.format(_end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(label),
          onPressed: () => _pickCustomRange(context),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _presetChip('This month', _thisMonth),
            _presetChip('Last month', _lastMonth),
            _presetChip('Last 3 months', _last3Months),
            _presetChip('This year', _thisYear),
          ],
        ),
      ],
    );
  }

  Widget _presetChip(String label, (DateTime, DateTime) Function() range) {
    final r = range();
    final selected = _start == r.$1 && _end == r.$2;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _start = r.$1;
        _end = r.$2;
      }),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _start, end: _end),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _start = DateUtils.dateOnly(picked.start);
      _end = DateUtils.dateOnly(picked.end);
    });
  }

  // Preset ranges as (inclusive start, inclusive end) day pairs.
  (DateTime, DateTime) _thisMonth() {
    final now = DateTime.now();
    return (
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 0),
    );
  }

  (DateTime, DateTime) _lastMonth() {
    final now = DateTime.now();
    return (
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month, 0),
    );
  }

  (DateTime, DateTime) _last3Months() {
    final now = DateTime.now();
    return (
      DateTime(now.year, now.month - 2, 1),
      DateTime(now.year, now.month + 1, 0),
    );
  }

  (DateTime, DateTime) _thisYear() {
    final now = DateTime.now();
    return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.report});

  final ReportSummary report;

  @override
  Widget build(BuildContext context) {
    final net = report.netMinor;
    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            row('Income', formatMinor(report.incomeMinor),
                color: Colors.green.shade700),
            row('Expenses', formatMinor(report.expenseMinor),
                color: Theme.of(context).colorScheme.error),
            const Divider(),
            row(
              'Net flow',
              '${net < 0 ? '-' : '+'}${formatMinor(net.abs())}',
              color: net < 0
                  ? Theme.of(context).colorScheme.error
                  : Colors.green.shade700,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.report, required this.byId});

  final ReportSummary report;
  final Map<String, Category> byId;

  @override
  Widget build(BuildContext context) {
    final total = report.expenseMinor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by category',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final spend in report.categorySpending)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          categoryIcon(byId[spend.categoryId]?.icon),
                          size: 16,
                          color: colorFromHex(byId[spend.categoryId]?.color),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            byId[spend.categoryId]?.name ?? 'Uncategorised',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '${formatMinor(spend.amountMinor)} · '
                          '${total == 0 ? 0 : (spend.amountMinor * 100 / total).round()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : spend.amountMinor / total,
                        minHeight: 6,
                        color: colorFromHex(byId[spend.categoryId]?.color),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
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

class _AccountBalancesCard extends StatelessWidget {
  const _AccountBalancesCard({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<int>(0, (s, a) => s + a.balanceMinor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accounts', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final account in accounts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      accountTypeIcon(account.type),
                      size: 16,
                      color: colorFromHex(account.color),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(account.name,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Text(
                      formatMinor(account.balanceMinor),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  formatMinor(total),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtSummaryCard extends StatelessWidget {
  const _DebtSummaryCard({required this.report});

  final ReportSummary report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debts', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Owed to you',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  formatMinor(report.owedToMeMinor),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('You owe',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  formatMinor(report.iOweMinor),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
