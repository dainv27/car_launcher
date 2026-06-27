import 'dart:async';
import 'dart:typed_data';
import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';

/// Search query for app drawer
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Load state for installed apps.
class InstalledAppsState {
  const InstalledAppsState({
    this.apps = const [],
    this.isLoading = true,
    this.hasLoaded = false,
  });

  final List<Map<String, String>> apps;
  final bool isLoading;
  final bool hasLoaded;

  InstalledAppsState copyWith({
    List<Map<String, String>>? apps,
    bool? isLoading,
    bool? hasLoaded,
  }) {
    return InstalledAppsState(
      apps: apps ?? this.apps,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}

/// Installed apps list — cached after first load
final installedAppsProvider =
    StateNotifierProvider<InstalledAppsNotifier, InstalledAppsState>((ref) {
      final launcher = ref.watch(launcherServiceProvider);
      final notifier = InstalledAppsNotifier(launcher);
      final packageChanges = NativeBridge.onEvent<Map>(
        'app_package_changed',
      ).listen((_) => notifier.refreshSoon());
      ref.onDispose(packageChanges.cancel);
      return notifier;
    });

class InstalledAppsNotifier extends StateNotifier<InstalledAppsState> {
  InstalledAppsNotifier(this._launcher) : super(const InstalledAppsState()) {
    _loadApps();
  }

  final LauncherService _launcher;
  int _requestGeneration = 0;
  Timer? _refreshDebounce;

  Future<void> _loadApps({bool force = false}) async {
    if (!mounted) return;
    if (!force && state.hasLoaded) return;

    final generation = ++_requestGeneration;
    state = state.copyWith(isLoading: true);

    try {
      final apps = await _launcher.getInstalledApps().timeout(
        const Duration(seconds: 30),
        onTimeout: () => <Map<String, String>>[],
      );
      if (!mounted || generation != _requestGeneration) return;
      apps.sort((a, b) => (a['appName'] ?? '').compareTo(b['appName'] ?? ''));
      state = InstalledAppsState(apps: apps, isLoading: false, hasLoaded: true);
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        state = const InstalledAppsState(
          apps: [],
          isLoading: false,
          hasLoaded: true,
        );
      }
    }
  }

  Future<void> refresh() => _loadApps(force: true);

  void refreshSoon() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  @override
  void dispose() {
    _requestGeneration++;
    _refreshDebounce?.cancel();
    super.dispose();
  }
}

/// Convenience provider for the app list.
final installedAppsListProvider = Provider<List<Map<String, String>>>((ref) {
  return ref.watch(installedAppsProvider).apps;
});

/// Whether installed apps are still loading.
final appsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(installedAppsProvider).isLoading;
});

/// Cached native launcher icon per package name.
final appIconProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  packageName,
) {
  if (packageName.isEmpty) return Future.value(null);
  return ref.read(launcherServiceProvider).getAppIconBytes(packageName);
});

/// Filtered apps based on search query
final filteredAppsProvider = Provider<List<Map<String, String>>>((ref) {
  final apps = ref.watch(installedAppsListProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  if (query.isEmpty) return apps;
  return apps.where((app) {
    final name = (app['appName'] ?? '').toLowerCase();
    final pkg = (app['packageName'] ?? '').toLowerCase();
    return name.contains(query) || pkg.contains(query);
  }).toList();
});

/// Recently launched apps — kept in memory, max 10
final recentAppsProvider =
    StateNotifierProvider<RecentAppsNotifier, List<Map<String, String>>>((ref) {
      return RecentAppsNotifier();
    });

class RecentAppsNotifier extends StateNotifier<List<Map<String, String>>> {
  RecentAppsNotifier() : super([]);

  void addRecent(Map<String, String> app) {
    // Remove if already exists, then add to front
    state = [
      app,
      ...state.where((a) => a['packageName'] != app['packageName']),
    ];
    // Keep only last 10
    if (state.length > 10) {
      state = state.sublist(0, 10);
    }
  }
}
