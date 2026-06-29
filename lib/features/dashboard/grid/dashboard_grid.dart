import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard_layout_provider.dart';
import '../model/dashboard_widget_spec.dart';
import '../model/dashboard_widget_type.dart';
import 'grid_packer.dart';

/// Height of one grid row-unit in logical pixels. A widget of height `h`
/// occupies `h * _rowHeight`.
const double _rowHeight = 80;
const double _gap = 12;
const int _columns = 4;

/// Renders the user's dashboard layout as a packed 4-column grid. In
/// [editing] mode each tile becomes draggable (to reorder) and gains
/// remove / resize / configure controls.
class DashboardGrid extends ConsumerWidget {
  const DashboardGrid({
    super.key,
    required this.editing,
    this.onConfigure,
  });

  final bool editing;
  final void Function(WidgetInstance instance)? onConfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(dashboardLayoutProvider);
    final widgets = layout.widgets;

    if (widgets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No widgets yet.\nTap Edit, then Add to build your dashboard.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final indexOf = {
      for (var i = 0; i < widgets.length; i++) widgets[i].id: i,
    };
    final pack = packTiles(widgets, columns: _columns);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / _columns;
        final gridHeight = pack.rows * _rowHeight;

        return SingleChildScrollView(
          child: SizedBox(
            height: gridHeight + 80, // bottom space clears the FAB
            child: Stack(
              children: [
                for (final tile in pack.tiles)
                  Positioned(
                    left: tile.col * cellW + _gap / 2,
                    top: tile.row * _rowHeight + _gap / 2,
                    width: tile.w * cellW - _gap,
                    height: tile.h * _rowHeight - _gap,
                    child: _GridTile(
                      instance: tile.instance,
                      index: indexOf[tile.instance.id]!,
                      editing: editing,
                      onConfigure: onConfigure,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridTile extends ConsumerWidget {
  const _GridTile({
    required this.instance,
    required this.index,
    required this.editing,
    required this.onConfigure,
  });

  final WidgetInstance instance;
  final int index;
  final bool editing;
  final void Function(WidgetInstance instance)? onConfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = kDashboardCatalog[instance.type];
    if (spec == null) return const SizedBox.shrink();
    final content = spec.builder(context, ref, instance);

    if (!editing) return content;

    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(dashboardLayoutProvider.notifier);

    final editableBody = Stack(
      children: [
        // The tile content, non-interactive while editing.
        Positioned.fill(child: IgnorePointer(child: content)),
        // Dashed-ish selection border.
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.primary, width: 1.5),
              ),
            ),
          ),
        ),
        // Configure (only for tiles that need it) — tap anywhere on the body.
        if (spec.needsConfig && onConfigure != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => onConfigure!(instance),
            ),
          ),
        // Remove.
        Positioned(
          top: 2,
          left: 2,
          child: _CircleButton(
            icon: Icons.close,
            color: scheme.error,
            onTap: () => notifier.remove(instance.id),
          ),
        ),
        // Resize (cycle) — only if more than one size is allowed.
        if (spec.allowedSizes.length > 1)
          Positioned(
            bottom: 2,
            right: 2,
            child: _CircleButton(
              icon: Icons.aspect_ratio,
              color: scheme.primary,
              onTap: () => notifier.cycleSize(instance.id),
            ),
          ),
      ],
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => notifier.move(details.data, index),
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return LongPressDraggable<int>(
          data: index,
          feedback: _DragFeedback(child: content),
          childWhenDragging: Opacity(opacity: 0.3, child: editableBody),
          child: Opacity(
            opacity: highlighted ? 0.6 : 1,
            child: editableBody,
          ),
        );
      },
    );
  }
}

/// Floating preview shown under the finger while dragging a tile. Sized to
/// match the tile via LayoutBuilder-free intrinsic; we wrap in Material so
/// shadows/ink render outside the normal tree.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The dragged feedback gets unbounded constraints; give it the same
    // footprint as a small tile so it reads as a card under the finger.
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: 0.9,
        child: SizedBox(width: 180, height: 120, child: child),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
