import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_layout_provider.dart';
import 'dashboard_providers.dart';
import 'grid/dashboard_grid.dart';
import 'model/dashboard_widget_type.dart';
import 'widget_catalog_sheet.dart';

/// The home screen. A fully user-customisable grid of widgets: tap Edit to
/// add, reorder (drag), resize, and remove tiles. Layout persists across
/// launches via [dashboardLayoutProvider].
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _editing = false;

  void _onConfigure(WidgetInstance instance) {
    if (instance.type == DashboardWidgetType.accountBalance) {
      showAccountPickerSheet(context, ref, instance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Ledger'),
        actions: [
          if (_editing) ...[
            IconButton(
              tooltip: 'Add widget',
              icon: const Icon(Icons.add),
              onPressed: () => showWidgetCatalogSheet(context, ref),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'reset') _confirmReset();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'reset',
                  child: Text('Reset to default'),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Done'),
            ),
          ] else
            IconButton(
              tooltip: 'Edit dashboard',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: summary == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: DashboardGrid(
                editing: _editing,
                onConfigure: _onConfigure,
              ),
            ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset dashboard?'),
        content: const Text(
            'This restores the default widgets and layout. Your current '
            'arrangement will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(dashboardLayoutProvider.notifier).resetToDefaults();
    }
  }
}
