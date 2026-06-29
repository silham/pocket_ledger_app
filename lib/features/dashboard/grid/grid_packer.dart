import '../model/dashboard_widget_type.dart';

/// A widget instance assigned a concrete cell position by the packer.
class PlacedTile {
  const PlacedTile({
    required this.instance,
    required this.col,
    required this.row,
  });

  final WidgetInstance instance;
  final int col;
  final int row;

  int get w => instance.w.clamp(1, 4);
  int get h => instance.h < 1 ? 1 : instance.h;
}

/// Result of packing: the placed tiles plus the total number of rows used.
class PackResult {
  const PackResult({required this.tiles, required this.rows});

  final List<PlacedTile> tiles;
  final int rows;
}

/// Packs [widgets] into a [columns]-wide grid (unbounded height), in list
/// order. Each widget takes the first free slot found scanning top→bottom,
/// left→right — so the result is gap-minimal and fully determined by order.
/// Pure: no Flutter, no clock. Easy to unit-test.
PackResult packTiles(List<WidgetInstance> widgets, {int columns = 4}) {
  final occupied = <List<bool>>[]; // occupied[row][col]
  final tiles = <PlacedTile>[];

  bool fits(int row, int col, int w, int h) {
    for (var r = row; r < row + h; r++) {
      for (var c = col; c < col + w; c++) {
        if (r < occupied.length && occupied[r][c]) return false;
      }
    }
    return true;
  }

  void ensureRows(int upto) {
    while (occupied.length < upto) {
      occupied.add(List<bool>.filled(columns, false));
    }
  }

  void mark(int row, int col, int w, int h) {
    ensureRows(row + h);
    for (var r = row; r < row + h; r++) {
      for (var c = col; c < col + w; c++) {
        occupied[r][c] = true;
      }
    }
  }

  for (final widget in widgets) {
    final w = widget.w.clamp(1, columns);
    final h = widget.h < 1 ? 1 : widget.h;
    var placed = false;
    for (var row = 0; !placed; row++) {
      for (var col = 0; col <= columns - w; col++) {
        ensureRows(row + 1);
        if (fits(row, col, w, h)) {
          mark(row, col, w, h);
          tiles.add(PlacedTile(instance: widget, col: col, row: row));
          placed = true;
          break;
        }
      }
    }
  }

  return PackResult(tiles: tiles, rows: occupied.length);
}
