import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app.dart';
import '../../../data/export_service.dart';
import '../../../data/import_service.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).set(selection.single),
            ),
          ),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Export backup (JSON)'),
            subtitle: const Text('Share a full copy of your data'),
            onTap: () => _exportBackup(ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restore from backup (JSON)'),
            subtitle: const Text('Replace all data with a backup file'),
            onTap: () => _restoreBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Verify balances'),
            subtitle: const Text('Recompute every account from its history'),
            onTap: () => _verifyBalances(ref),
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Pocket Ledger'),
            subtitle: Text('Local-first personal finance tracker'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(WidgetRef ref) async {
    try {
      final json =
          await ExportService(ref.read(databaseProvider)).buildJson();
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('${dir.path}/pocket_ledger_backup_$stamp.json');
      await file.writeAsString(json);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Pocket Ledger backup $stamp',
      ));
    } catch (e) {
      showAppSnackBar('Export failed: $e');
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This replaces everything in the app — accounts, transactions, '
          'people, categories and budgets — with the contents of the backup '
          "file. Your current data is deleted and this can't be undone.\n\n"
          'Export a backup first if you might need your current data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null) return; // User cancelled the picker.

      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        showAppSnackBar('Could not read that file.');
        return;
      }

      final result = await ImportService(ref.read(databaseProvider))
          .restoreJson(utf8.decode(bytes));
      showAppSnackBar('Restored ${result.total} records from backup');
    } on ImportException catch (e) {
      showAppSnackBar(e.message);
    } catch (e) {
      showAppSnackBar('Restore failed: $e');
    }
  }

  Future<void> _verifyBalances(WidgetRef ref) async {
    final mismatches =
        await ref.read(ledgerServiceProvider).verifyAccountBalances();
    showAppSnackBar(
      mismatches.isEmpty
          ? 'All account balances check out'
          : '${mismatches.length} account(s) out of sync — please report this',
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
