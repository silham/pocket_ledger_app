import 'dart:convert';

import 'package:uuid/uuid.dart';

/// The kinds of widget the dashboard can show. The string [name] is the stable
/// key persisted in JSON — never rename an existing value (add new ones only).
enum DashboardWidgetType {
  totalBalance,
  statSpentToday,
  statNet30,
  statIncome30,
  statSpent30,
  debt,
  balanceChart,
  spendingPie,
  accountBalance,
  spendingByDay,
  recentTransactions,
}

/// A widget footprint in grid cells: [w] columns (1–4) × [h] row-units.
class GridSize {
  const GridSize(this.w, this.h);

  final int w;
  final int h;

  @override
  bool operator ==(Object other) =>
      other is GridSize && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(w, h);
}

const _uuid = Uuid();

/// One placed widget on the dashboard: a type, its current size, and any
/// per-instance configuration (e.g. which account for [accountBalance]).
class WidgetInstance {
  WidgetInstance({
    required this.id,
    required this.type,
    required this.w,
    required this.h,
    this.config = const {},
  });

  /// Creates a fresh instance with a generated id.
  factory WidgetInstance.create({
    required DashboardWidgetType type,
    required GridSize size,
    Map<String, dynamic> config = const {},
  }) =>
      WidgetInstance(
        id: _uuid.v4(),
        type: type,
        w: size.w,
        h: size.h,
        config: config,
      );

  final String id;
  final DashboardWidgetType type;
  final int w;
  final int h;
  final Map<String, dynamic> config;

  GridSize get size => GridSize(w, h);

  WidgetInstance copyWith({int? w, int? h, Map<String, dynamic>? config}) =>
      WidgetInstance(
        id: id,
        type: type,
        w: w ?? this.w,
        h: h ?? this.h,
        config: config ?? this.config,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'w': w,
        'h': h,
        if (config.isNotEmpty) 'config': config,
      };

  /// Returns null when the persisted type is unknown to this build (so the
  /// loader can drop it for forward-compatibility).
  static WidgetInstance? fromJson(Map<String, dynamic> json) {
    DashboardWidgetType? type;
    for (final t in DashboardWidgetType.values) {
      if (t.name == json['type']) {
        type = t;
        break;
      }
    }
    if (type == null) return null;
    return WidgetInstance(
      id: json['id'] as String? ?? _uuid.v4(),
      type: type,
      w: (json['w'] as num?)?.toInt() ?? 2,
      h: (json['h'] as num?)?.toInt() ?? 1,
      config: (json['config'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// The ordered list of widgets shown on the dashboard. Order drives packing.
class DashboardLayout {
  const DashboardLayout(this.widgets);

  final List<WidgetInstance> widgets;

  /// The original fixed home screen, reproduced as a default layout.
  factory DashboardLayout.defaults() => DashboardLayout([
        WidgetInstance.create(
            type: DashboardWidgetType.totalBalance, size: const GridSize(4, 2)),
        WidgetInstance.create(
            type: DashboardWidgetType.statSpentToday,
            size: const GridSize(2, 1)),
        WidgetInstance.create(
            type: DashboardWidgetType.statNet30, size: const GridSize(2, 1)),
        WidgetInstance.create(
            type: DashboardWidgetType.statIncome30, size: const GridSize(2, 1)),
        WidgetInstance.create(
            type: DashboardWidgetType.statSpent30, size: const GridSize(2, 1)),
        WidgetInstance.create(
            type: DashboardWidgetType.debt, size: const GridSize(4, 1)),
        WidgetInstance.create(
            type: DashboardWidgetType.balanceChart,
            size: const GridSize(4, 4)),
        WidgetInstance.create(
            type: DashboardWidgetType.spendingPie, size: const GridSize(4, 3)),
        WidgetInstance.create(
            type: DashboardWidgetType.recentTransactions,
            size: const GridSize(4, 4)),
      ]);

  String toJson() => jsonEncode(widgets.map((w) => w.toJson()).toList());

  /// Parses a persisted layout, dropping any entries with unknown types.
  /// Returns null on malformed input so callers can fall back to defaults.
  static DashboardLayout? tryParse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! List) return null;
    final widgets = <WidgetInstance>[];
    for (final item in decoded) {
      if (item is Map) {
        final instance =
            WidgetInstance.fromJson(item.cast<String, dynamic>());
        if (instance != null) widgets.add(instance);
      }
    }
    return DashboardLayout(widgets);
  }
}
