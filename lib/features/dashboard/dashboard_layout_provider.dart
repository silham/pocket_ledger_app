import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/dashboard_widget_spec.dart';
import 'model/dashboard_widget_type.dart';

/// The user's dashboard layout, persisted in shared_preferences as a JSON
/// blob (same pattern as [themeModeProvider]). Starts as the default layout
/// and upgrades to the saved value once prefs load. Mutators write through
/// to prefs so changes survive restarts.
final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, DashboardLayout>(
        DashboardLayoutNotifier.new);

class DashboardLayoutNotifier extends Notifier<DashboardLayout> {
  static const _prefsKey = 'dashboard_layout';

  @override
  DashboardLayout build() {
    _load();
    return DashboardLayout.defaults();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final parsed = DashboardLayout.tryParse(raw);
      if (parsed != null) state = parsed;
    } catch (_) {
      // No prefs available (tests): keep the default layout.
    }
  }

  Future<void> _persist(DashboardLayout layout) async {
    state = layout;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, layout.toJson());
    } catch (_) {}
  }

  List<WidgetInstance> get _widgets => List.of(state.widgets);

  /// Appends a new widget of [type] at its default size.
  void add(DashboardWidgetType type) {
    final spec = kDashboardCatalog[type];
    if (spec == null) return;
    _persist(DashboardLayout([
      ..._widgets,
      WidgetInstance.create(type: type, size: spec.defaultSize),
    ]));
  }

  void remove(String id) {
    _persist(DashboardLayout(_widgets..removeWhere((w) => w.id == id)));
  }

  /// Moves the widget at [oldIndex] so it sits at [newIndex] in reading order.
  void move(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final widgets = _widgets;
    if (oldIndex < 0 || oldIndex >= widgets.length) return;
    final item = widgets.removeAt(oldIndex);
    final target = newIndex.clamp(0, widgets.length);
    widgets.insert(target, item);
    _persist(DashboardLayout(widgets));
  }

  /// Cycles a widget to the next size in its spec's allowed list (wraps).
  void cycleSize(String id) {
    final spec = _specFor(id);
    if (spec == null || spec.allowedSizes.length < 2) return;
    _persist(DashboardLayout([
      for (final w in state.widgets)
        if (w.id == id)
          w.copyWith(
            w: _nextSize(spec, w.size).w,
            h: _nextSize(spec, w.size).h,
          )
        else
          w,
    ]));
  }

  void setConfig(String id, Map<String, dynamic> config) {
    _persist(DashboardLayout([
      for (final w in state.widgets)
        if (w.id == id) w.copyWith(config: config) else w,
    ]));
  }

  void resetToDefaults() => _persist(DashboardLayout.defaults());

  DashboardWidgetSpec? _specFor(String id) {
    for (final w in state.widgets) {
      if (w.id == id) return kDashboardCatalog[w.type];
    }
    return null;
  }

  GridSize _nextSize(DashboardWidgetSpec spec, GridSize current) {
    final sizes = spec.allowedSizes;
    final i = sizes.indexWhere((s) => s == current);
    return sizes[(i + 1) % sizes.length];
  }
}
