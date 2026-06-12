import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/color_hex.dart';

/// Horizontal swatch row used by the account and category forms.
class PalettePicker extends StatelessWidget {
  const PalettePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pickerColors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hex = pickerColors[index];
          final isSelected = hex == selected;
          return GestureDetector(
            onTap: () => onChanged(hex),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorFromHex(hex),
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        width: 3,
                        color: Theme.of(context).colorScheme.onSurface,
                      )
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
