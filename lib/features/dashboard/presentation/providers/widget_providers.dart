import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/features/dashboard/domain/widget_model.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';

/// Widget list notifier — manages dashboard widget layout with persistence
class WidgetListNotifier extends StateNotifier<List<WidgetModel>> {
  WidgetListNotifier(this._prefs) : super([]) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    final json = _prefs.getString(AppConstants.keyWidgets);
    if (json == null || json.isEmpty) return;
    try {
      final list = jsonDecode(json) as List;
      state = list
          .map((e) => WidgetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.instance.d('Widget list load failed — using empty', tag: 'WIDGETS', error: e);
      state = [];
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(state.map((w) => w.toJson()).toList());
    await _prefs.setString(AppConstants.keyWidgets, json);
  }

  void addWidget(WidgetType type) {
    final id = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    final widget = WidgetModel(
      id: id,
      type: type,
      width: WidgetRegistry.defaultWidths[type] ?? 1,
      height: WidgetRegistry.defaultHeights[type] ?? 1,
    );
    state = [...state, widget];
    _save();
  }

  void removeWidget(String id) {
    state = state.where((w) => w.id != id).toList();
    _save();
  }

  void updateWidget(WidgetModel updated) {
    state = state.map((w) => w.id == updated.id ? updated : w).toList();
    _save();
  }

  void moveWidget(String id, int x, int y) {
    state = state.map((w) => w.id == id ? w.copyWith(x: x, y: y) : w).toList();
    _save();
  }

  void resizeWidget(String id, int width, int height) {
    state =
        state.map((w) => w.id == id ? w.copyWith(width: width, height: height) : w).toList();
    _save();
  }
}

/// Provider for the widget list
final widgetListProvider =
    StateNotifierProvider<WidgetListNotifier, List<WidgetModel>>((ref) {
  throw UnimplementedError('Provider must be overridden with SharedPreferences');
});

/// Currently selected widget ID (for edit mode)
final selectedWidgetIdProvider = StateProvider<String?>((ref) => null);

/// Whether the dashboard is in edit mode
final editModeProvider = StateProvider<bool>((ref) => false);

/// Widget being dragged (for drag & drop)
final draggingWidgetIdProvider = StateProvider<String?>((ref) => null);
