import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../data/transactions_repository.dart';
import '../../domain/ledger/deltas.dart';
import '../../providers/data_providers.dart';

class PersonWithBalance {
  const PersonWithBalance({required this.person, required this.netMinor});

  final Person person;

  /// Positive = they owe the user; negative = the user owes them.
  final int netMinor;
}

/// A person's history split into the still-open episode and older, fully
/// settled transactions.
class DebtHistorySplit {
  const DebtHistorySplit({required this.unsettled, required this.settled});

  /// The current, still-open run of lends/borrows (newest first). Empty when
  /// the person is fully settled.
  final List<TransactionListItem> unsettled;

  /// Older transactions that have already netted back to zero (newest first).
  final List<TransactionListItem> settled;
}

/// Splits [newestFirst] (the order the repository returns) into settled history
/// and the current open balance.
///
/// Walking oldest→newest, each time the running balance returns to zero the
/// debt is square, so everything up to and including that point is settled.
/// The open episode is whatever comes after the *last* zero point — those are
/// the records the user still needs to act on.
DebtHistorySplit splitDebtHistory(List<TransactionListItem> newestFirst) {
  final chronological = newestFirst.reversed.toList();
  var running = 0;
  // Count of oldest transactions that are fully settled.
  var settledCount = 0;
  for (var i = 0; i < chronological.length; i++) {
    running += personDeltaOf(chronological[i].transaction);
    if (running == 0) settledCount = i + 1;
  }

  // Back to newest-first for display.
  return DebtHistorySplit(
    unsettled: chronological.sublist(settledCount).reversed.toList(),
    settled: chronological.sublist(0, settledCount).reversed.toList(),
  );
}

/// Active people with derived net balances, biggest debts first.
final peopleWithBalancesProvider = Provider<List<PersonWithBalance>?>((ref) {
  final people = ref.watch(activePeopleProvider).value;
  final transactions = ref.watch(allActiveTransactionsProvider).value;
  if (people == null || transactions == null) return null;

  final nets = <String, int>{};
  for (final t in transactions) {
    final delta = personDeltaOf(t);
    if (delta != 0 && t.personId != null) {
      nets.update(t.personId!, (v) => v + delta, ifAbsent: () => delta);
    }
  }

  return [
    for (final p in people)
      PersonWithBalance(person: p, netMinor: nets[p.id] ?? 0),
  ]..sort((a, b) => b.netMinor.abs().compareTo(a.netMinor.abs()));
});

final personProvider = StreamProvider.family<Person?, String>(
  (ref, id) => ref.watch(peopleRepositoryProvider).watchById(id),
);

/// A person's lend/borrow/settlement history, newest first.
final personHistoryProvider =
    StreamProvider.family<List<TransactionListItem>, String>(
  (ref, personId) =>
      ref.watch(transactionsRepositoryProvider).watchAll(personId: personId),
);

/// Net balance for one person, derived from the same data as the list.
final personNetProvider = Provider.family<int?, String>((ref, personId) {
  final all = ref.watch(peopleWithBalancesProvider);
  if (all == null) return null;
  for (final p in all) {
    if (p.person.id == personId) return p.netMinor;
  }
  // Archived people are not in the active list; fall back to history.
  final history = ref.watch(personHistoryProvider(personId)).value;
  if (history == null) return null;
  return history.fold<int>(
      0, (sum, item) => sum + personDeltaOf(item.transaction));
});
