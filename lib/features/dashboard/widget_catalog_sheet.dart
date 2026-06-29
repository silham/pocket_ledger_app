import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../providers/data_providers.dart';
import 'dashboard_layout_provider.dart';
import 'model/dashboard_widget_spec.dart';
import 'model/dashboard_widget_type.dart';

/// Bottom sheet listing every widget in the catalog. Tapping one adds it to
/// the layout at its default size (and immediately opens the account picker
/// for the configurable types).
Future<void> showWidgetCatalogSheet(BuildContext context, WidgetRef ref) {
  // The screen context — outlives the sheet, so it's safe for the follow-up
  // account picker after the catalog sheet is popped.
  final screenContext = context;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final specs = kDashboardCatalog.values.toList();
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Add a widget',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final spec in specs)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(spec.icon,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 20),
                  ),
                  title: Text(spec.title),
                  subtitle: Text(spec.description),
                  trailing: const Icon(Icons.add),
                  onTap: () {
                    final notifier =
                        ref.read(dashboardLayoutProvider.notifier);
                    notifier.add(spec.type);
                    Navigator.of(sheetContext).pop();
                    // For configurable widgets, prompt for the binding now.
                    if (spec.needsConfig) {
                      final ofType = ref
                          .read(dashboardLayoutProvider)
                          .widgets
                          .where((w) => w.type == spec.type)
                          .toList();
                      final added = ofType.isEmpty ? null : ofType.last;
                      if (added != null && screenContext.mounted) {
                        showAccountPickerSheet(screenContext, ref, added);
                      }
                    }
                  },
                ),
            ],
          );
        },
      );
    },
  );
}

/// Sheet that binds an [instance] (an "account balance" tile) to one of the
/// user's active accounts.
Future<void> showAccountPickerSheet(
  BuildContext context,
  WidgetRef ref,
  WidgetInstance instance,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final accounts = ref.watch(activeAccountsProvider).value ?? const [];
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Choose an account',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (accounts.isEmpty)
                  const ListTile(
                    title: Text('No accounts yet'),
                    subtitle: Text('Add an account first.'),
                  ),
                for (final account in accounts)
                  ListTile(
                    leading: const Icon(Icons.account_balance_outlined),
                    title: Text(account.name),
                    subtitle: Text(formatMinor(account.balanceMinor)),
                    selected: instance.config['accountId'] == account.id,
                    onTap: () {
                      ref.read(dashboardLayoutProvider.notifier).setConfig(
                        instance.id,
                        {'accountId': account.id},
                      );
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
