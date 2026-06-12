import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../data/transactions_repository.dart';
import '../../domain/models/enums.dart';
import '../../providers/data_providers.dart';
import 'transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionType? _filter;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(transactionListProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
          ),
          for (final type in TransactionType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(type.label),
                selected: _filter == type,
                onSelected: (_) => setState(() => _filter = type),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupedTransactionList extends ConsumerWidget {
  const _GroupedTransactionList({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Flatten into [header, row, row, header, row...] keyed by calendar day.
    final entries = <Widget>[];
    DateTime? currentDay;
    for (final item in items) {
      final local = item.transaction.date.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day != currentDay) {
        currentDay = day;
        entries.add(_DayHeader(day: day));
      }
      entries.add(_DismissibleTile(item: item));
    }

    return ListView(children: entries);
  }
}

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
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
            'Account balances will be restored as if it never happened.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = switch (today.difference(day).inDays) {
      0 => 'Today',
      1 => 'Yesterday',
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
            'No transactions yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add your first one',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
