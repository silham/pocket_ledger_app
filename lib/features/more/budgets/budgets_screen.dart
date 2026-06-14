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

/// Recurring default budgets (null month + year).
final defaultBudgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(budgetsRepositoryProvider).watchDefaults(),
);

/// Month-specific override budgets for a given month.
final budgetsForMonthProvider =
    StreamProvider.family<List<Budget>, MonthKey>((ref, key) {
  return ref.watch(budgetsRepositoryProvider).watchMonth(key.year, key.month);
});

/// Where an effective budget came from for the selected month.
enum BudgetSource { defaultRecurring, monthOverride }

/// A single resolved budget line: the amount in force for the month, what was
/// spent against it, and the underlying default / override rows behind it.
class BudgetLine {
  const BudgetLine({
    required this.categoryId,
    required this.amountMinor,
    required this.spentMinor,
    required this.source,
    required this.override,
    required this.defaultBudget,
  });

  /// null = the overall budget.
  final String? categoryId;
  final int amountMinor;
  final int spentMinor;
  final BudgetSource source;

  /// This month's override row, if one exists.
  final Budget? override;

  /// The recurring default row, if one exists.
  final Budget? defaultBudget;

  bool get isOverall => categoryId == null;

  double get fraction => amountMinor == 0 ? 0 : spentMinor / amountMinor;

  /// The row currently in force (override wins over default).
  Budget get effective => source == BudgetSource.monthOverride
      ? override!
      : defaultBudget!;
}

class BudgetSummary {
  const BudgetSummary({required this.overall, required this.categories});

  /// null when no overall budget (default or override) is set.
  final BudgetLine? overall;
  final List<BudgetLine> categories;
}

Budget? _overallOf(List<Budget> list) {
  for (final b in list) {
    if (b.isOverall) return b;
  }
  return null;
}

/// Resolves defaults + month overrides + spending into the lines the UI shows.
final budgetSummaryProvider =
    Provider.family<BudgetSummary?, MonthKey>((ref, key) {
  final defaults = ref.watch(defaultBudgetsProvider).value;
  final overrides = ref.watch(budgetsForMonthProvider(key)).value;
  final transactions = ref.watch(allActiveTransactionsProvider).value;
  final categories = ref.watch(allCategoriesProvider).value;
  if (defaults == null ||
      overrides == null ||
      transactions == null ||
      categories == null) {
    return null;
  }

  final excludedFromOverall = {
    for (final c in categories)
      if (!c.includeInOverallBudget) c.id,
  };

  var overallSpent = 0;
  final spentByCategory = <String, int>{};
  for (final t in transactions) {
    if (t.type != TransactionType.expense) continue;
    final local = t.date.toLocal();
    if (local.year != key.year || local.month != key.month) continue;
    final cid = t.categoryId;
    if (cid == null || !excludedFromOverall.contains(cid)) {
      overallSpent += t.amountMinor;
    }
    if (cid != null) {
      spentByCategory.update(cid, (v) => v + t.amountMinor,
          ifAbsent: () => t.amountMinor);
    }
  }

  BudgetLine? buildLine({
    required String? categoryId,
    required Budget? override,
    required Budget? defaultBudget,
    required int spentMinor,
  }) {
    final effective = override ?? defaultBudget;
    if (effective == null) return null;
    return BudgetLine(
      categoryId: categoryId,
      amountMinor: effective.amountMinor,
      spentMinor: spentMinor,
      source: override != null
          ? BudgetSource.monthOverride
          : BudgetSource.defaultRecurring,
      override: override,
      defaultBudget: defaultBudget,
    );
  }

  final overall = buildLine(
    categoryId: null,
    override: _overallOf(overrides),
    defaultBudget: _overallOf(defaults),
    spentMinor: overallSpent,
  );

  final defaultByCat = {
    for (final b in defaults)
      if (!b.isOverall && b.categoryId != null) b.categoryId!: b,
  };
  final overrideByCat = {
    for (final b in overrides)
      if (!b.isOverall && b.categoryId != null) b.categoryId!: b,
  };

  final categoryLines = <BudgetLine>[];
  for (final cid in {...defaultByCat.keys, ...overrideByCat.keys}) {
    final line = buildLine(
      categoryId: cid,
      override: overrideByCat[cid],
      defaultBudget: defaultByCat[cid],
      spentMinor: spentByCategory[cid] ?? 0,
    );
    if (line != null) categoryLines.add(line);
  }
  categoryLines.sort((a, b) => b.fraction.compareTo(a.fraction));

  return BudgetSummary(overall: overall, categories: categoryLines);
});

/// Which scope an edit targets in the editor sheet.
enum _Scope { thisMonth, defaultRecurring }

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
    final summary = ref.watch(budgetSummaryProvider(_key));
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final byId = {for (final c in categories) c.id: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Column(
        children: [
          _MonthSelector(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          Expanded(
            child: summary == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _SectionHeader(
                        title: 'Overall',
                        actionLabel:
                            summary.overall == null ? 'Set' : null,
                        onAction: () => _showOverallSheet(line: null),
                      ),
                      if (summary.overall == null)
                        _UnsetCard(
                          label: 'No overall budget',
                          hint: 'Set a monthly limit across all spending',
                          onTap: () => _showOverallSheet(line: null),
                        )
                      else
                        _BudgetCard(
                          line: summary.overall!,
                          category: null,
                          onTap: () =>
                              _showOverallSheet(line: summary.overall),
                          onRemove: () => _removeLine(summary.overall!),
                        ),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: 'Categories',
                        actionLabel: 'Add',
                        onAction: () => _showCategorySheet(line: null),
                      ),
                      if (summary.categories.isEmpty)
                        const _UnsetCard(
                          label: 'No category budgets',
                          hint: 'Add a per-category limit',
                          onTap: null,
                        )
                      else
                        for (final line in summary.categories)
                          _BudgetCard(
                            line: line,
                            category: byId[line.categoryId],
                            onTap: () => _showCategorySheet(line: line),
                            onRemove: () => _removeLine(line),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeLine(BudgetLine line) async {
    await ref.read(budgetsRepositoryProvider).delete(line.effective.id);
    showAppSnackBar(
      line.source == BudgetSource.monthOverride
          ? "This month's budget removed"
          : 'Default budget removed',
    );
  }

  // ---- Overall editor -----------------------------------------------------

  Future<void> _showOverallSheet({BudgetLine? line}) async {
    var scope = (line?.override != null)
        ? _Scope.thisMonth
        : _Scope.defaultRecurring;
    final amountController = TextEditingController();

    Budget? rowFor(_Scope s) =>
        s == _Scope.thisMonth ? line?.override : line?.defaultBudget;
    void syncAmount() {
      final row = rowFor(scope);
      amountController.text =
          row == null ? '' : minorToInputString(row.amountMinor);
    }

    syncAmount();

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Overall monthly budget',
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 16),
                _ScopeSelector(
                  scope: scope,
                  monthLabel: DateFormat('MMM yyyy').format(_month),
                  onChanged: (s) => setSheetState(() {
                    scope = s;
                    syncAmount();
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: scope == _Scope.thisMonth
                        ? "This month's limit"
                        : 'Default monthly limit',
                    prefixText: 'Rs. ',
                  ),
                ),
                const SizedBox(height: 8),
                const _IncludedCategoriesTile(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (rowFor(scope) != null)
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            await ref
                                .read(budgetsRepositoryProvider)
                                .delete(rowFor(scope)!.id);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            showAppSnackBar('Budget removed');
                          },
                          child: const Text('Remove'),
                        ),
                      ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _saveScoped(
                          sheetContext,
                          scope: scope,
                          amountText: amountController.text,
                          categoryId: null,
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Category editor ----------------------------------------------------

  Future<void> _showCategorySheet({BudgetLine? line}) async {
    final expenseCategories =
        await ref.read(activeCategoriesProvider(CategoryType.expense).future);
    if (!mounted) return;
    if (line == null && expenseCategories.isEmpty) {
      showAppSnackBar('Add an expense category first');
      return;
    }

    var categoryId = line?.categoryId ?? expenseCategories.first.id;
    var scope = (line?.override != null)
        ? _Scope.thisMonth
        : _Scope.defaultRecurring;
    final amountController = TextEditingController();

    Budget? rowFor(_Scope s) =>
        s == _Scope.thisMonth ? line?.override : line?.defaultBudget;
    void syncAmount() {
      final row = rowFor(scope);
      amountController.text =
          row == null ? '' : minorToInputString(row.amountMinor);
    }

    syncAmount();

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(line == null ? 'Add category budget' : 'Category budget',
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 16),
                if (line == null)
                  DropdownMenu<String>(
                    initialSelection: categoryId,
                    label: const Text('Category'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: [
                      for (final c in expenseCategories)
                        DropdownMenuEntry<String>(
                          value: c.id,
                          label: c.name,
                          leadingIcon: Icon(categoryIcon(c.icon)),
                        ),
                    ],
                    onSelected: (v) {
                      if (v != null) categoryId = v;
                    },
                  ),
                if (line == null) const SizedBox(height: 16),
                _ScopeSelector(
                  scope: scope,
                  monthLabel: DateFormat('MMM yyyy').format(_month),
                  onChanged: (s) => setSheetState(() {
                    scope = s;
                    syncAmount();
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: scope == _Scope.thisMonth
                        ? "This month's limit"
                        : 'Default monthly limit',
                    prefixText: 'Rs. ',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (rowFor(scope) != null)
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            await ref
                                .read(budgetsRepositoryProvider)
                                .delete(rowFor(scope)!.id);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            showAppSnackBar('Budget removed');
                          },
                          child: const Text('Remove'),
                        ),
                      ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _saveScoped(
                          sheetContext,
                          scope: scope,
                          amountText: amountController.text,
                          categoryId: categoryId,
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveScoped(
    BuildContext sheetContext, {
    required _Scope scope,
    required String amountText,
    required String? categoryId,
  }) async {
    final amount = parseAmountToMinor(amountText);
    if (amount == null) {
      showAppSnackBar('Enter a valid amount');
      return;
    }
    await ref.read(budgetsRepositoryProvider).setBudget(
          year: scope == _Scope.thisMonth ? _month.year : null,
          month: scope == _Scope.thisMonth ? _month.month : null,
          amountMinor: amount,
          categoryId: categoryId,
        );
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    showAppSnackBar('Budget saved');
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.scope,
    required this.monthLabel,
    required this.onChanged,
  });

  final _Scope scope;
  final String monthLabel;
  final ValueChanged<_Scope> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Scope>(
      segments: [
        const ButtonSegment(
          value: _Scope.defaultRecurring,
          label: Text('Every month'),
          icon: Icon(Icons.repeat),
        ),
        ButtonSegment(
          value: _Scope.thisMonth,
          label: Text(monthLabel),
          icon: const Icon(Icons.event),
        ),
      ],
      selected: {scope},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Live list of expense categories with a toggle for overall-budget inclusion.
class _IncludedCategoriesTile extends ConsumerWidget {
  const _IncludedCategoriesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(activeCategoriesProvider(CategoryType.expense)).value ??
            const <Category>[];
    final excluded = categories.where((c) => !c.includeInOverallBudget).length;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Included categories'),
        subtitle: Text(excluded == 0
            ? 'All spending counts toward the overall budget'
            : '$excluded excluded'),
        children: [
          for (final c in categories)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: c.includeInOverallBudget,
              title: Text(c.name),
              secondary: Icon(categoryIcon(c.icon),
                  color: colorFromHex(c.color)),
              onChanged: (v) => ref
                  .read(categoriesRepositoryProvider)
                  .setIncludedInOverall(c.id, v),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onAction,
    this.actionLabel,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 18),
            label: Text(actionLabel!),
          ),
      ],
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
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

class _UnsetCard extends StatelessWidget {
  const _UnsetCard({required this.label, required this.hint, this.onTap});

  final String label;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.add_chart, color: colorScheme.onSurfaceVariant),
        title: Text(label),
        subtitle: Text(hint),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.line,
    required this.category,
    required this.onTap,
    required this.onRemove,
  });

  final BudgetLine line;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = line.fraction;
    final percent = (fraction * 100).round();

    final Color barColor;
    String? statusText;
    if (fraction > 1) {
      barColor = colorScheme.error;
      statusText =
          'Over by ${formatMinor(line.spentMinor - line.amountMinor)}';
    } else if (fraction >= 0.8) {
      barColor = Colors.orange.shade800;
      statusText = 'Almost there';
    } else {
      barColor = Colors.green.shade700;
    }

    final title =
        line.isOverall ? 'Overall' : category?.name ?? 'Unknown category';

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!line.isOverall)
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
                  _SourceChip(source: line.source),
                  const SizedBox(width: 8),
                  Text('$percent%',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: barColor)),
                  PopupMenuButton<String>(
                    onSelected: (action) =>
                        action == 'remove' ? onRemove() : onTap(),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
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
                '${formatMinor(line.spentMinor)} of '
                '${formatMinor(line.amountMinor)}'
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

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final BudgetSource source;

  @override
  Widget build(BuildContext context) {
    final isOverride = source == BudgetSource.monthOverride;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOverride
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOverride ? 'This month' : 'Default',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isOverride
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
