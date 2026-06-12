import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money/money.dart';
import '../../core/router/app_router.dart';
import 'people_providers.dart';
import 'person_form.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleWithBalancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add person',
            onPressed: () => showPersonForm(context, ref),
          ),
        ],
      ),
      body: switch (people) {
        null => const Center(child: CircularProgressIndicator()),
        [] => const _EmptyState(),
        final list => ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) =>
                _PersonTile(entry: list[index]),
          ),
      },
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.entry});

  final PersonWithBalance entry;

  @override
  Widget build(BuildContext context) {
    final net = entry.netMinor;
    final colorScheme = Theme.of(context).colorScheme;
    final (statusText, statusColor) = switch (net.sign) {
      1 => ('owes you', Colors.green.shade700),
      -1 => ('you owe', colorScheme.error),
      _ => ('settled', colorScheme.onSurfaceVariant),
    };

    return ListTile(
      onTap: () => context.push(AppRoutes.personLedger(entry.person.id)),
      leading: CircleAvatar(child: Text(_initials(entry.person.name))),
      title: Text(entry.person.name),
      subtitle: Text(statusText),
      trailing: Text(
        net == 0 ? '—' : formatMinor(net.abs()),
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p[0].toUpperCase());
    return letters.join();
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
            Icons.group_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('No people yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Add someone to track lending and borrowing',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
