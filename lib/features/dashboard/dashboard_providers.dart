import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dashboard/dashboard_summary.dart';
import '../../providers/data_providers.dart';

/// Derived dashboard stats. Null while the underlying streams are loading.
/// Recomputes automatically on every database write (the source providers
/// are Drift streams).
final dashboardSummaryProvider = Provider<DashboardSummary?>((ref) {
  final accounts = ref.watch(activeAccountsProvider).value;
  final transactions = ref.watch(allActiveTransactionsProvider).value;
  if (accounts == null || transactions == null) return null;
  return DashboardSummary.compute(
    accounts: accounts,
    transactions: transactions,
    now: DateTime.now(),
  );
});
