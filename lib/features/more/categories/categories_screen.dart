import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/db/app_database.dart';
import '../../../core/utils/app_icons.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/widgets/palette_picker.dart';
import '../../../domain/models/enums.dart';
import '../../../providers/data_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ]),
          actions: [
            Builder(
              builder: (tabContext) => IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add category',
                onPressed: () {
                  final type = DefaultTabController.of(tabContext).index == 0
                      ? CategoryType.expense
                      : CategoryType.income;
                  _showForm(tabContext, ref, type: type);
                },
              ),
            ),
          ],
        ),
        body: TabBarView(children: [
          _CategoryList(type: CategoryType.expense, onEdit: _showForm),
          _CategoryList(type: CategoryType.income, onEdit: _showForm),
        ]),
      ),
    );
  }

  static Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    required CategoryType type,
    Category? category,
  }) {
    final nameController = TextEditingController(text: category?.name);
    var color = category?.color ?? pickerColors.first;
    var icon = category?.icon ?? 'other';

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
                category == null
                    ? 'New ${type == CategoryType.expense ? 'expense' : 'income'} category'
                    : 'Edit category',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: category == null,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryIcons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final key = categoryIcons.keys.elementAt(index);
                    final isSelected = key == icon;
                    return IconButton(
                      icon: Icon(categoryIcons[key]),
                      isSelected: isSelected,
                      style: isSelected
                          ? IconButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                            )
                          : null,
                      onPressed: () => setSheetState(() => icon = key),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
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
                  final repo = ref.read(categoriesRepositoryProvider);
                  if (category == null) {
                    await repo.create(
                        name: name, type: type, icon: icon, color: color);
                  } else {
                    await repo.update(category.id,
                        name: name, icon: icon, color: color);
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  showAppSnackBar(
                      category == null ? 'Category added' : 'Category updated');
                },
                child: Text(category == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type, required this.onEdit});

  final CategoryType type;
  final Future<void> Function(
    BuildContext,
    WidgetRef, {
    required CategoryType type,
    Category? category,
  }) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(activeCategoriesProvider(type)).value;
    if (categories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        for (final category in categories)
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  colorFromHex(category.color).withValues(alpha: 0.18),
              child: Icon(
                categoryIcon(category.icon),
                color: colorFromHex(category.color),
                size: 20,
              ),
            ),
            title: Text(category.name),
            subtitle: category.isDefault ? const Text('Default') : null,
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'edit') {
                  await onEdit(context, ref,
                      type: type, category: category);
                } else if (action == 'archive') {
                  await ref
                      .read(categoriesRepositoryProvider)
                      .archive(category.id);
                  showAppSnackBar('${category.name} archived');
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
            onTap: () => onEdit(context, ref, type: type, category: category),
          ),
      ],
    );
  }
}
