import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/db/app_database.dart';
import '../../core/money/money.dart';
import '../../core/router/app_router.dart';
import '../../data/transactions_repository.dart';
import '../../domain/models/enums.dart';
import '../../providers/data_providers.dart';
import '../transactions/transaction_tile.dart';
import 'people_providers.dart';
import 'person_form.dart';

class PersonLedgerScreen extends ConsumerWidget {
  const PersonLedgerScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(personId)).value;
    final net = ref.watch(personNetProvider(personId));
    final history = ref.watch(personHistoryProvider(personId)).value;

    if (person == null || net == null || history == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final split = splitDebtHistory(history);

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'edit') {
                await showPersonForm(context, ref, person: person);
              } else if (action == 'archive') {
                final confirmed = await _confirmArchive(context, person.name);
                if (confirmed == true) {
                  await ref.read(peopleRepositoryProvider).archive(personId);
                  showAppSnackBar('${person.name} archived');
                  if (context.mounted) context.pop();
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceHeader(person: person, netMinor: net),
          const SizedBox(height: 12),
          if (net != 0) _SettleButton(personId: personId, netMinor: net),
          const SizedBox(height: 16),
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No lending or borrowing with ${person.name} yet.\n'
                'Use the + button to record a lend or borrow.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          else ...[
            for (final item in split.unsettled)
              TransactionTile(item: item, showDate: true),
            if (split.settled.isNotEmpty) _SettledHistory(items: split.settled),
          ],
        ],
      ),
    );
  }

  Future<bool?> _confirmArchive(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive $name?'),
        content: const Text(
            'Their history is kept, but they disappear from the People list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.person, required this.netMinor});

  final Person person;
  final int netMinor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (netMinor.sign) {
      1 => ('owes you', Colors.green.shade700),
      -1 => ('you owe', colorScheme.error),
      _ => ('All settled', colorScheme.onSurfaceVariant),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              netMinor == 0
                  ? 'All settled'
                  : '${person.name} $label',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              formatMinor(netMinor.abs()),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (person.phone != null || person.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                [person.phone, person.notes]
                    .whereType<String>()
                    .join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Collapsed run of transactions that already netted back to zero. Kept out of
/// the way so only the open balance is front-and-centre, but still reachable.
class _SettledHistory extends StatelessWidget {
  const _SettledHistory({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.check_circle_outline),
        title: const Text('Settled history'),
        subtitle: Text('$count fully repaid '
            '${count == 1 ? 'transaction' : 'transactions'}'),
        childrenPadding: EdgeInsets.zero,
        children: [
          for (final item in items) TransactionTile(item: item, showDate: true),
        ],
      ),
    );
  }
}

class _SettleButton extends StatelessWidget {
  const _SettleButton({required this.personId, required this.netMinor});

  final String personId;
  final int netMinor;

  @override
  Widget build(BuildContext context) {
    // They owe you -> you receive money; you owe them -> you pay.
    final type = netMinor > 0
        ? TransactionType.settlementReceived
        : TransactionType.settlementPaid;

    return FilledButton.icon(
      icon: const Icon(Icons.handshake_outlined),
      label: Text(netMinor > 0 ? 'Record repayment' : 'Pay back'),
      onPressed: () => context.push(
        '${AppRoutes.add}?type=${type.name}'
        '&person=$personId&amount=${netMinor.abs()}',
      ),
    );
  }
}
