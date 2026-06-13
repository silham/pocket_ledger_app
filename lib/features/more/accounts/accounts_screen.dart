import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/app_icons.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/widgets/palette_picker.dart';
import '../../../domain/models/enums.dart';
import '../../../providers/data_providers.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add account',
            onPressed: () => _showForm(context, ref),
          ),
        ],
      ),
      body: accounts == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final account in accounts)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          colorFromHex(account.color).withValues(alpha: 0.18),
                      child: Icon(
                        accountTypeIcon(account.type),
                        color: colorFromHex(account.color),
                        size: 20,
                      ),
                    ),
                    title: Text(account.name),
                    subtitle: Text(accountTypeLabel(account.type)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMinor(account.balanceMinor),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) =>
                              _onAction(context, ref, account, action),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'adjust',
                                child: Text('Adjust balance')),
                            PopupMenuItem(
                                value: 'archive', child: Text('Archive')),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _showForm(context, ref, account: account),
                  ),
              ],
            ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    Account account,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await _showForm(context, ref, account: account);
      case 'adjust':
        context.push(
            '${AppRoutes.add}?type=adjustment&account=${account.id}');
      case 'archive':
        final accounts = await ref.read(activeAccountsProvider.future);
        if (accounts.length <= 1) {
          showAppSnackBar('You need at least one active account');
          return;
        }
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Archive ${account.name}?'),
            content: const Text(
                'Its history is kept, but it disappears from pickers and totals.'),
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
        if (confirmed == true) {
          await ref.read(accountsRepositoryProvider).archive(account.id);
          showAppSnackBar('${account.name} archived');
        }
    }
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref,
      {Account? account}) {
    final nameController = TextEditingController(text: account?.name);
    var type = account?.type ?? AccountType.cash;
    var color = account?.color ?? pickerColors.first;

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
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
                account == null ? 'New account' : 'Edit account',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: account == null,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownMenu<AccountType>(
                initialSelection: type,
                label: const Text('Type'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
                  for (final t in AccountType.values)
                    DropdownMenuEntry(
                      value: t,
                      label: accountTypeLabel(t),
                      leadingIcon: Icon(accountTypeIcon(t)),
                    ),
                ],
                onSelected: (t) => type = t ?? type,
              ),
              const SizedBox(height: 16),
              PalettePicker(
                selected: color,
                onChanged: (hex) => setSheetState(() => color = hex),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    showAppSnackBar('Name is required');
                    return;
                  }
                  final repo = ref.read(accountsRepositoryProvider);
                  if (account == null) {
                    await repo.create(name: name, type: type, color: color);
                  } else {
                    await repo.update(account.id,
                        name: name, type: type, color: color);
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  showAppSnackBar(
                      account == null ? 'Account added' : 'Account updated');
                },
                child: Text(account == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
