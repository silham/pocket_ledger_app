import 'package:flutter/material.dart';

/// Bottom-sheet picker used across the app (accounts, categories, people).
/// Large touch targets per the UX principles in the plan.
Future<T?> showSelectorSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required Widget Function(BuildContext, T) tileBuilder,
  Widget? footer,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (itemContext, index) =>
                    tileBuilder(itemContext, items[index]),
              ),
            ),
            ?footer,
          ],
        ),
      ),
    ),
  );
}
