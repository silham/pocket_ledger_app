import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/db/app_database.dart';
import '../../providers/data_providers.dart';

/// Create (person == null) or edit a person via a bottom sheet.
Future<void> showPersonForm(
  BuildContext context,
  WidgetRef ref, {
  Person? person,
}) {
  final nameController = TextEditingController(text: person?.name);
  final phoneController = TextEditingController(text: person?.phone);
  final emailController = TextEditingController(text: person?.email);
  final notesController = TextEditingController(text: person?.notes);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
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
            person == null ? 'New person' : 'Edit person',
            style: Theme.of(sheetContext).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            autofocus: person == null,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                showAppSnackBar('Name is required');
                return;
              }
              String? clean(TextEditingController c) =>
                  c.text.trim().isEmpty ? null : c.text.trim();

              final repo = ref.read(peopleRepositoryProvider);
              if (person == null) {
                await repo.create(
                  name,
                  phone: clean(phoneController),
                  email: clean(emailController),
                );
              } else {
                await repo.update(
                  person.id,
                  name: name,
                  phone: clean(phoneController),
                  email: clean(emailController),
                  notes: clean(notesController),
                );
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              showAppSnackBar(person == null ? 'Person added' : 'Person updated');
            },
            child: Text(person == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    ),
  );
}
