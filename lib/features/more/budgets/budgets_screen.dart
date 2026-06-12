import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/app_icons.dart';
import '../../../core/utils/color_hex.dart';
import '../../../domain/models/enums.dart';
import '../../../providers/data_providers.dart';

typedef MonthKey = ({int year, int month});

final budgetsForMonthProvider =
    StreamProvider.family<List<Budget>, MonthKey>((ref, key) {
  return ref
      .watch(budgetsRepositoryProvider)
      .watchMonth(key.year, key.month);
});

class BudgetProgress {
  const BudgetProgress({required this.budget, required this.spentMinor});

  final Budget budget;
  final int spentMinor;

  double get fraction =>
      budget.amountMinor == 0 ? 0 : spentMinor / budget.amountMinor;
}

/// Budgets for the month with their spending, overall budget first.
final budgetProgressProvider =
    Provider.family<List<BudgetProgress>?, MonthKey>((ref, key) {
  final budgets = ref.watch(budgetsForMonthProvider(key)).value;
  final transactions = ref.watch(allActiveTransactionsProvider).value;
  if (budgets == null || transactions == null) return null;

  var totalExpense = 0;
  final byCategory = <String, int>{};
  for (final t in transactions) {
    if (t.type != TransactionType.expense) continue;
    final local = t.date.toLocal();
    if (local.year != key.year || local.month != key.month) continue;
    totalExpense += t.amountMinor;
    if (t.categoryId != null) {
      byCategory.update(t.categoryId!, (v) => v + t.amountMinor,
          ifAbsent: () => t.amountMinor);
    }
  }

  final list = [
    for (final b in budgets)
      BudgetProgress(
        budget: b,
        spentMinor:
            b.isOverall ? totalExpense : (byCategory[b.categoryId] ?? 0),
      ),
  ]..sort((a, b) {
      if (a.budget.isOverall != b.budget.isOverall) {
        return a.budget.isOverall ? -1 : 1;
      }
      return b.fraction.compareTo(a.fraction);
    });
  return list;
});

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  MonthKey get _key => (year: _month.year, month: _month.month);

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(budgetProgressProvider(_key));
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final byId = {for (final c in categories) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Set budget',
            onPressed: () => _showForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthSelector(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          Expanded(
            child: switch (progress) {
              null => const Center(child: CircularProgressIndicator()),
              [] => const _EmptyState(),
              final list => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final p in list)
                      _BudgetCard(
                        progress: p,
                        category: byId[p.budget.categoryId],
                        onEdit: () => _showForm(context, existing: p.budget),
                        onDelete: () async {
                          await ref
                              .read(budgetsRepositoryProvider)
                              .delete(p.budget.id);
                          showAppSnackBar('Budget removed');
                        },
                      ),
                  ],
                ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showForm(BuildContext context, {Budget? existing}) async {
    final amountController = TextEditingController(
      text: existing == null ? '' : minorToInputString(existing.amountMinor),
    );
    // null sentinel = overall budget.
    String? categoryId = existing?.categoryId;
    final expenseCategories =
        await ref.read(activeCategoriesProvider(CategoryType.expense).future);
    if (!context.mounted) return;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? 'Set budget' : 'Edit budget',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMMM yyyy').format(_month),
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (existing == null)
                DropdownMenu<String?>(
                  initialSelection: categoryId,
                  label: const Text('Scope'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    const DropdownMenuEntry<String?>(
                      value: null,
                      label: 'Overall (all spending)',
                    ),
                    for (final c in expenseCategories)
                      DropdownMenuEntry<String?>(
                        value: c.id,
                        label: c.name,
                        leadingIcon: Icon(categoryIcon(c.icon)),
                      ),
                  ],
                  onSelected: (v) => categoryId = v,
                ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monthly limit',
                  prefixText: 'Rs. ',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final amount = parseAmountToMinor(amountController.text);
                  if (amount == null) {
                    showAppSnackBar('Enter a valid amount');
                    return;
                  }
                  await ref.read(budgetsRepositoryProvider).setBudget(
                        year: _month.year,
                        month: _month.month,
                        amountMinor: amount,
                        categoryId:
                            existing == null ? categoryId : existing.categoryId,
                      );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  showAppSnackBar('Budget saved');
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                onChanged(DateTime(month.year, month.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.progress,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetProgress progress;
  final Category? category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final budget = progress.budget;
    final fraction = progress.fraction;
    final percent = (fraction * 100).round();

    final Color barColor;
    String? statusText;
    if (fraction > 1) {
      barColor = colorScheme.error;
      statusText =
          'Over by ${formatMinor(progress.spentMinor - budget.amountMinor)}';
    } else if (fraction >= 0.8) {
      barColor = Colors.orange.shade800;
      statusText = 'Almost there';
    } else {
      barColor = Colors.green.shade700;
    }

    final title = budget.isOverall
        ? 'Overall'
        : category?.name ?? 'Unknown category';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!budget.isOverall)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        categoryIcon(category?.icon),
                        size: 18,
                        color: colorFromHex(category?.color),
                      ),
                    ),
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Text('$percent%',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: barColor)),
                  PopupMenuButton<String>(
                    onSelected: (action) =>
                        action == 'delete' ? onDelete() : onEdit(),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0, 1),
                  minHeight: 8,
                  color: barColor,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatMinor(progress.spentMinor)} of '
                '${formatMinor(budget.amountMinor)}'
                '${statusText == null ? '' : ' · $statusText'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('No budgets for this month',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap + to set an overall or category limit',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
