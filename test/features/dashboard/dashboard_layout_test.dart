import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/features/dashboard/model/dashboard_widget_type.dart';

void main() {
  test('defaults reproduce the original home screen widgets', () {
    final types = DashboardLayout.defaults().widgets.map((w) => w.type).toList();
    expect(types, contains(DashboardWidgetType.totalBalance));
    expect(types, contains(DashboardWidgetType.balanceChart));
    expect(types, contains(DashboardWidgetType.spendingPie));
    expect(
      types.where((t) => t.name.startsWith('stat')).length,
      4,
      reason: 'four stat tiles',
    );
  });

  test('layout round-trips through JSON, preserving order and config', () {
    final original = DashboardLayout([
      WidgetInstance.create(
          type: DashboardWidgetType.totalBalance, size: const GridSize(4, 2)),
      WidgetInstance.create(
        type: DashboardWidgetType.accountBalance,
        size: const GridSize(2, 1),
        config: {'accountId': 'abc-123'},
      ),
    ]);

    final restored = DashboardLayout.tryParse(original.toJson())!;
    expect(restored.widgets, hasLength(2));
    expect(restored.widgets[0].type, DashboardWidgetType.totalBalance);
    expect(restored.widgets[0].w, 4);
    expect(restored.widgets[0].h, 2);
    expect(restored.widgets[1].type, DashboardWidgetType.accountBalance);
    expect(restored.widgets[1].config['accountId'], 'abc-123');
  });

  test('unknown widget types are dropped on load', () {
    const raw = '[{"id":"1","type":"totalBalance","w":4,"h":2},'
        '{"id":"2","type":"someFutureWidget","w":2,"h":1}]';
    final restored = DashboardLayout.tryParse(raw)!;
    expect(restored.widgets, hasLength(1));
    expect(restored.widgets.single.type, DashboardWidgetType.totalBalance);
  });

  test('malformed JSON parses to null so callers can fall back', () {
    expect(DashboardLayout.tryParse('not json'), isNull);
    expect(DashboardLayout.tryParse('{"not":"a list"}'), isNull);
  });
}
