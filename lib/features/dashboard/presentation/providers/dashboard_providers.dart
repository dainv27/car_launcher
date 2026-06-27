import 'dart:async';

import 'package:car_launcher/core/auth/app_secure_storage.dart';
import 'package:car_launcher/core/auth/app_secure_storage_keys.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time provider — updates every second
final clockProvider = StateNotifierProvider<ClockNotifier, String>((ref) {
  return ClockNotifier();
});

class ClockNotifier extends StateNotifier<String> {
  ClockNotifier() : super(_formatTime(DateTime.now())) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = _formatTime(DateTime.now());
    });
  }

  late final Timer _timer;

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

/// Typed connectivity status model replacing raw Map<String, dynamic>.
class ConnectivityStatus {
  const ConnectivityStatus({
    this.isConnected = false,
    this.type = 'unknown',
    this.signalStrength = 0,
    this.isRoaming = false,
    this.extra = const {},
  });

  final bool isConnected;
  final String type;
  final int signalStrength;
  final bool isRoaming;
  final Map<String, dynamic> extra;

  factory ConnectivityStatus.fromMap(Map<String, dynamic> map) {
    return ConnectivityStatus(
      isConnected: map['isConnected'] as bool? ?? map['connected'] as bool? ?? false,
      type: (map['type'] ?? map['connectionType'] ?? 'unknown').toString(),
      signalStrength: (map['signalStrength'] ?? map['signal'] ?? 0).toInt(),
      isRoaming: map['isRoaming'] as bool? ?? map['roaming'] as bool? ?? false,
      extra: Map<String, dynamic>.from(map)..removeWhere((k, v) =>
        {'isConnected', 'connected', 'type', 'connectionType',
         'signalStrength', 'signal', 'isRoaming', 'roaming'}.contains(k)),
    );
  }

  Map<String, dynamic> toMap() => {
    'isConnected': isConnected,
    'type': type,
    'signalStrength': signalStrength,
    'isRoaming': isRoaming,
    ...extra,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectivityStatus &&
          isConnected == other.isConnected &&
          type == other.type &&
          signalStrength == other.signalStrength &&
          isRoaming == other.isRoaming;

  @override
  int get hashCode => Object.hash(isConnected, type, signalStrength, isRoaming);

  static const empty = ConnectivityStatus();
}

/// Connectivity status from native
final connectivityStatusProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>((ref) {
  final launcher = ref.watch(launcherServiceProvider);
  return ConnectivityNotifier(launcher, NativeBridge.events);
});

class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityNotifier(this._launcher, Stream<dynamic> events) : super(ConnectivityStatus.empty) {
    _refresh();
    _subscription = events.where((event) => event is Map).cast<Map>().listen((event) {
      _requestGeneration++;
      if (mounted) {
        state = ConnectivityStatus.fromMap(Map<String, dynamic>.from(event));
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  final LauncherService _launcher;
  late final Timer _timer;
  late final StreamSubscription<dynamic> _subscription;
  int _requestGeneration = 0;

  Future<void> _refresh() async {
    final generation = ++_requestGeneration;
    try {
      final status = await _launcher.getConnectivityStatus();
      if (mounted && generation == _requestGeneration) {
        state = ConnectivityStatus.fromMap(status);
      }
    } catch (e) {
      AppLogger.instance.w('Connectivity refresh failed', tag: 'CONNECTIVITY', error: e);
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    _timer.cancel();
    _subscription.cancel();
    super.dispose();
  }
}

/// Current wallpaper path (empty = default)
final currentWallpaperProvider = StateNotifierProvider<WallpaperNotifier, String>((ref) {
  return WallpaperNotifier();
});

class WallpaperNotifier extends StateNotifier<String> {
  WallpaperNotifier() : super('');

  Future<void> setWallpaper(String path) async {
    state = path;
  }
}

/// Favorite apps for quick access
final favoriteAppsProvider = StateNotifierProvider<FavoriteAppsNotifier, List<Map<String, String>>>((ref) {
  return FavoriteAppsNotifier();
});

class FavoriteAppsNotifier extends StateNotifier<List<Map<String, String>>> {
  FavoriteAppsNotifier() : super([]);

  void addFavorite(Map<String, String> app) {
    if (state.length < 5) {
      state = [...state, app];
    }
  }

  void removeFavorite(String packageName) {
    state = state.where((a) => a['packageName'] != packageName).toList();
  }
}

final dashboardIndexProvider = StateNotifierProvider<DashboardIndexNotifier, int>((ref) {
  return DashboardIndexNotifier();
});

class DashboardIndexNotifier extends StateNotifier<int> {
  DashboardIndexNotifier() : super(_default) {
    _load();
  }
  static final int _default = 2;

  Future<void> _load() async {
    final value = await AppSecureStorage.instance.read(key: AppSecureStorageKeys.dashboardIndex);

    final index = int.tryParse(value ?? '');

    if (index != null) {
      state = index;
    }
  }

  Future<void> setIndex(int i) async {
    if (state == i) return;

    state = i;

    await AppSecureStorage.instance.write(key: AppSecureStorageKeys.dashboardIndex, value: i.toString());
  }

  Future<void> reset() async {
    if (state == _default) return;

    state = _default;

    await AppSecureStorage.instance.write(key: AppSecureStorageKeys.dashboardIndex, value: _default.toString());
  }
}
