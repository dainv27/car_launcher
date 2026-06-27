import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';

enum HomeViewMode {
  dashboard01,
  dashboard02,
  dashboard03,
  multiApp;

  String get displayName {
    switch (this) {
      case HomeViewMode.dashboard01:
        return 'Map Focus';
      case HomeViewMode.dashboard02:
        return 'Grid Layout';
      case HomeViewMode.dashboard03:
        return 'Split View';
      case HomeViewMode.multiApp:
        return 'Multi App';
    }
  }

  String get description {
    switch (this) {
      case HomeViewMode.dashboard01:
        return 'Full-screen map with YouTube overlay';
      case HomeViewMode.dashboard02:
        return 'Map + media + weather grid';
      case HomeViewMode.dashboard03:
        return 'Map and YouTube side by side';
      case HomeViewMode.multiApp:
        return 'Split-screen with embedded apps';
    }
  }
}

class CarPlaySettings {
  const CarPlaySettings({
    this.homeViewMode = HomeViewMode.dashboard03,
    this.dynamicClockNetwork = true,
    this.use24HourTime = true,
    this.showVpnStatus = true,
    this.dockPinned = false,
  });

  final HomeViewMode homeViewMode;
  final bool dynamicClockNetwork;
  final bool use24HourTime;
  final bool showVpnStatus;
  final bool dockPinned;

  CarPlaySettings copyWith({
    HomeViewMode? homeViewMode,
    bool? dynamicClockNetwork,
    bool? use24HourTime,
    bool? showVpnStatus,
    bool? dockPinned,
  }) {
    return CarPlaySettings(
      homeViewMode: homeViewMode ?? this.homeViewMode,
      dynamicClockNetwork: dynamicClockNetwork ?? this.dynamicClockNetwork,
      use24HourTime: use24HourTime ?? this.use24HourTime,
      showVpnStatus: showVpnStatus ?? this.showVpnStatus,
      dockPinned: dockPinned ?? this.dockPinned,
    );
  }
}

final carPlaySettingsProvider =
    StateNotifierProvider<CarPlaySettingsNotifier, CarPlaySettings>((ref) {
  throw UnimplementedError('Override with SharedPreferences in main.dart');
});

class CarPlaySettingsNotifier extends StateNotifier<CarPlaySettings> {
  CarPlaySettingsNotifier(this._prefs) : super(const CarPlaySettings()) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    final modeName = _prefs.getString(AppConstants.keyHomeViewMode);
    final mode = HomeViewMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => HomeViewMode.dashboard03,
    );
    state = CarPlaySettings(
      homeViewMode: mode,
      dynamicClockNetwork:
          _prefs.getBool(AppConstants.keyDynamicClockNetwork) ?? true,
      use24HourTime: _prefs.getBool(AppConstants.keyUse24HourTime) ?? true,
      showVpnStatus: _prefs.getBool(AppConstants.keyShowVpnStatus) ?? true,
      dockPinned: _prefs.getBool(AppConstants.keyDockPinned) ?? false,
    );
  }

  Future<void> setHomeViewMode(HomeViewMode mode) async {
    state = state.copyWith(homeViewMode: mode);
    await _prefs.setString(AppConstants.keyHomeViewMode, mode.name);
  }

  Future<void> setDynamicClockNetwork(bool value) async {
    state = state.copyWith(dynamicClockNetwork: value);
    await _prefs.setBool(AppConstants.keyDynamicClockNetwork, value);
  }

  Future<void> setUse24HourTime(bool value) async {
    state = state.copyWith(use24HourTime: value);
    await _prefs.setBool(AppConstants.keyUse24HourTime, value);
  }

  Future<void> setShowVpnStatus(bool value) async {
    state = state.copyWith(showVpnStatus: value);
    await _prefs.setBool(AppConstants.keyShowVpnStatus, value);
  }

  Future<void> setDockPinned(bool value) async {
    state = state.copyWith(dockPinned: value);
    await _prefs.setBool(AppConstants.keyDockPinned, value);
  }
}

/// Whether clock/network overlays are currently visible (dynamic hide/show).
final overlayVisibleProvider = StateNotifierProvider<OverlayVisibleNotifier, bool>(
  (ref) => OverlayVisibleNotifier(ref),
);

class OverlayVisibleNotifier extends StateNotifier<bool> {
  OverlayVisibleNotifier(this._ref) : super(true);

  final Ref _ref;
  Timer? _timer;

  void onUserInteraction() {
    final settings = _ref.read(carPlaySettingsProvider);
    if (!settings.dynamicClockNetwork || settings.dockPinned) return;

    state = false;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) state = true;
    });
  }

  void showNow() => state = true;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
