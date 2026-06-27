import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';

/// Layout notifier — manages layout configuration with persistence
class LayoutNotifier extends StateNotifier<LayoutModel> {
  LayoutNotifier(this._prefs) : super(const LayoutModel()) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    final json = _prefs.getString(AppConstants.keyLayout);
    if (json == null || json.isEmpty) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      state = LayoutModel.fromJson(map);
    } catch (e) {
      AppLogger.instance.d('Layout load failed — using default', tag: 'LAYOUT', error: e);
      state = const LayoutModel();
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(state.toJson());
    await _prefs.setString(AppConstants.keyLayout, json);
  }

  /// Change the layout type
  Future<void> setType(LayoutType type) async {
    state = state.copyWith(type: type);
    await _save();
  }

  /// Change the pane ratio
  Future<void> setRatio(LayoutRatio ratio) async {
    state = state.copyWith(ratio: ratio);
    await _save();
  }

  /// Assign an app to a specific pane
  Future<void> assignApp(int paneIndex, PaneApp app) async {
    final apps = List<PaneApp>.from(state.paneApps);
    // Ensure the list is long enough
    while (apps.length <= paneIndex) {
      apps.add(const PaneApp(packageName: '', appName: ''));
    }
    apps[paneIndex] = app;
    state = state.copyWith(paneApps: apps);
    await _save();
  }

  /// Remove an app from a specific pane
  Future<void> removeApp(int paneIndex) async {
    if (paneIndex < 0 || paneIndex >= state.paneApps.length) return;
    final apps = List<PaneApp>.from(state.paneApps);
    apps.removeAt(paneIndex);
    state = state.copyWith(paneApps: apps);
    await _save();
  }

  /// Clear all app assignments
  Future<void> clearAssignments() async {
    state = state.copyWith(paneApps: []);
    await _save();
  }
}

/// Provider for layout configuration
final layoutProvider =
    StateNotifierProvider<LayoutNotifier, LayoutModel>((ref) {
  throw UnimplementedError('Provider must be overridden with SharedPreferences');
});

/// Convenience provider for just the layout type
final layoutTypeProvider = Provider<LayoutType>((ref) {
  return ref.watch(layoutProvider).type;
});

/// Convenience provider for just the layout ratio
final layoutRatioProvider = Provider<LayoutRatio>((ref) {
  return ref.watch(layoutProvider).ratio;
});

/// Provider for the app assigned to a specific pane
final paneAppProvider = Provider.family<PaneApp?, int>((ref, paneIndex) {
  return ref.watch(layoutProvider).appForPane(paneIndex);
});
