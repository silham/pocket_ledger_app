import 'package:flutter/material.dart';

/// Shared frame for every dashboard tile. Fills its grid cell (the grid gives
/// it tight bounds) with the app's flat 16px-radius card. Gaps between tiles
/// are handled by the grid, so the card itself has no margin.
class TileCard extends StatelessWidget {
  const TileCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Tile header line (small caps-ish label), used by the chart tiles.
class TileTitle extends StatelessWidget {
  const TileTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}
