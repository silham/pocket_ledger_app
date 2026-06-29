import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/features/dashboard/grid/grid_packer.dart';
import 'package:pocket_ledger_app/features/dashboard/model/dashboard_widget_type.dart';

void main() {
  WidgetInstance tile(int w, int h, [String? id]) => WidgetInstance(
        id: id ?? '$w x $h',
        type: DashboardWidgetType.totalBalance,
        w: w,
        h: h,
      );

  test('a single 4x2 tile sits at the origin and uses 2 rows', () {
    final result = packTiles([tile(4, 2)]);
    expect(result.rows, 2);
    expect(result.tiles.single.col, 0);
    expect(result.tiles.single.row, 0);
  });

  test('two 2x1 tiles share the first row side by side', () {
    final result = packTiles([tile(2, 1, 'a'), tile(2, 1, 'b')]);
    expect(result.rows, 1);
    expect(result.tiles[0].col, 0);
    expect(result.tiles[0].row, 0);
    expect(result.tiles[1].col, 2);
    expect(result.tiles[1].row, 0);
  });

  test('a full-width tile after two halves drops to the next row', () {
    final result = packTiles([tile(2, 1), tile(2, 1), tile(4, 1)]);
    expect(result.rows, 2);
    expect(result.tiles[2].col, 0);
    expect(result.tiles[2].row, 1);
  });

  test('order drives placement: no tile overlaps another', () {
    final result = packTiles([
      tile(4, 2, 'total'),
      tile(2, 1, 's1'),
      tile(2, 1, 's2'),
      tile(4, 4, 'chart'),
      tile(2, 2, 'acct'),
    ]);

    // Build an occupancy grid and assert every cell is claimed at most once.
    final occupied = <String>{};
    for (final t in result.tiles) {
      for (var r = t.row; r < t.row + t.h; r++) {
        for (var c = t.col; c < t.col + t.w; c++) {
          final key = '$r,$c';
          expect(occupied.contains(key), isFalse,
              reason: 'cell $key claimed twice');
          occupied.add(key);
          expect(c, lessThan(4), reason: 'tile escapes the 4-col grid');
        }
      }
    }
  });

  test('oversized width is clamped to the column count', () {
    final result = packTiles([tile(9, 1)]);
    expect(result.tiles.single.w, 4);
    expect(result.tiles.single.col, 0);
  });
}
