import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/money/money.dart';
import '../../core/router/app_router.dart';
import '../../data/transactions_repository.dart';
import '../../domain/models/enums.dart';

/// One transaction row. Used by the history list (wrapped in a Dismissible)
/// and the dashboard's recent-transactions section. Tapping opens edit.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context) {
    final t = item.transaction;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => context.push('${AppRoutes.add}?edit=${t.id}'),
      leading: CircleAvatar(
        backgroundColor: _typeColor(t.type).withValues(alpha: 0.15),
        child: Icon(_typeIcon(t.type), color: _typeColor(t.type), size: 20),
      ),
      title: Text(_title()),
      subtitle: Text(_subtitle()),
      trailing: Text(
        _amountText(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _amountColor(colorScheme),
            ),
      ),
    );
  }

  String _title() {
    final t = item.transaction;
    return switch (t.type) {
      TransactionType.expense ||
      TransactionType.income =>
        item.categoryName ?? t.type.label,
      TransactionType.transfer =>
        '${item.accountName} → ${item.toAccountName ?? '?'}',
      TransactionType.adjustment => 'Balance adjustment',
      _ => '${t.type.label} · ${item.personName ?? '?'}',
    };
  }

  String _subtitle() {
    final t = item.transaction;
    final note = t.note;
    final base =
        t.type == TransactionType.transfer ? t.type.label : item.accountName;
    return note == null || note.isEmpty ? base : '$base · $note';
  }

  String _amountText() {
    final t = item.transaction;
    final amount = formatMinor(t.amountMinor);
    if (t.type == TransactionType.adjustment) {
      return t.isNegativeAdjustment ? '-$amount' : '+$amount';
    }
    return switch (t.type.displaySign) {
      1 => '+$amount',
      -1 => '-$amount',
      _ => amount,
    };
  }

  Color _amountColor(ColorScheme scheme) {
    final t = item.transaction;
    final sign = t.type == TransactionType.adjustment
        ? (t.isNegativeAdjustment ? -1 : 1)
        : t.type.displaySign;
    return switch (sign) {
      1 => Colors.green.shade700,
      -1 => scheme.error,
      _ => scheme.onSurface,
    };
  }

  static IconData _typeIcon(TransactionType type) => switch (type) {
        TransactionType.expense => Icons.arrow_upward,
        TransactionType.income => Icons.arrow_downward,
        TransactionType.transfer => Icons.swap_horiz,
        TransactionType.lend => Icons.call_made,
        TransactionType.borrow => Icons.call_received,
        TransactionType.settlementReceived => Icons.task_alt,
        TransactionType.settlementPaid => Icons.price_check,
        TransactionType.adjustment => Icons.tune,
      };

  static Color _typeColor(TransactionType type) => switch (type) {
        TransactionType.expense => Colors.red,
        TransactionType.income => Colors.green,
        TransactionType.transfer => Colors.blue,
        TransactionType.lend => Colors.orange,
        TransactionType.borrow => Colors.purple,
        TransactionType.settlementReceived => Colors.teal,
        TransactionType.settlementPaid => Colors.amber.shade800,
        TransactionType.adjustment => Colors.blueGrey,
      };
}
