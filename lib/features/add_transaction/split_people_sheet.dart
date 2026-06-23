import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

/// Multi-select bottom sheet for choosing the people in a split. Returns the
/// chosen set, or null if dismissed. Kept separate from the single-select
/// [showSelectorSheet] so that helper stays simple.
///
/// [onAddPerson] lets the caller create a brand-new person inline (reusing the
/// add screen's create dialog); the new person is appended and pre-selected.
Future<Set<Person>?> showSplitPeopleSheet({
  required BuildContext context,
  required List<Person> people,
  required Set<Person> selected,
  required Future<Person?> Function() onAddPerson,
}) {
  return showModalBottomSheet<Set<Person>>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _SplitPeopleSheet(
      people: people,
      initialSelected: selected,
      onAddPerson: onAddPerson,
    ),
  );
}

class _SplitPeopleSheet extends StatefulWidget {
  const _SplitPeopleSheet({
    required this.people,
    required this.initialSelected,
    required this.onAddPerson,
  });

  final List<Person> people;
  final Set<Person> initialSelected;
  final Future<Person?> Function() onAddPerson;

  @override
  State<_SplitPeopleSheet> createState() => _SplitPeopleSheetState();
}

class _SplitPeopleSheetState extends State<_SplitPeopleSheet> {
  late final List<Person> _people = [...widget.people];
  late final Set<String> _selectedIds =
      widget.initialSelected.map((p) => p.id).toSet();

  Future<void> _addPerson() async {
    final created = await widget.onAddPerson();
    if (created == null || !mounted) return;
    setState(() {
      if (_people.every((p) => p.id != created.id)) _people.add(created);
      _selectedIds.add(created.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Who shared this?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final person in _people)
                    CheckboxListTile(
                      value: _selectedIds.contains(person.id),
                      title: Text(person.name),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selectedIds.add(person.id);
                        } else {
                          _selectedIds.remove(person.id);
                        }
                      }),
                    ),
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined),
                    title: const Text('Add new person'),
                    onTap: _addPerson,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _people.where((p) => _selectedIds.contains(p.id)).toSet(),
                ),
                child: Text('Done (${_selectedIds.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
