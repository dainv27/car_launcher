import 'dart:async';

import 'package:car_launcher/core/api/api_config.dart';
import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';
import 'package:car_launcher/features/tracking/data/tracking_store_service.dart';
import 'package:car_launcher/features/tracking/domain/vehicle_track_point.dart';
import 'package:car_launcher/features/vehicle/data/vehicle_api_client.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VehicleTrackingState {
  const VehicleTrackingState({
    this.enabled = false,
    this.points = const [],
    this.distanceMeters = 0,
    this.isLoading = false,
    this.syncEndpoint = '',
    this.vehicle = const Vehicle(),
    this.vehicles = const [],
    this.isLoadingVehicles = false,
    this.lastVehicleError,
    this.isSyncing = false,
    this.lastSyncError,
  });

  final bool enabled;
  final List<VehicleTrackPoint> points;
  final double distanceMeters;
  final bool isLoading;
  final String syncEndpoint;
  final Vehicle vehicle;
  final List<Vehicle> vehicles;
  final bool isLoadingVehicles;
  final String? lastVehicleError;
  final bool isSyncing;
  final String? lastSyncError;

  VehicleTrackPoint? get lastPoint => points.isEmpty ? null : points.last;

  int get pointCount => points.length;

  int get pendingSyncCount => points.where((point) => !point.synced).length;

  bool get hasRoute => points.length > 1;

  bool get canSync => vehicle.id.isNotEmpty && pendingSyncCount > 0;

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  VehicleTrackingState copyWith({
    bool? enabled,
    List<VehicleTrackPoint>? points,
    double? distanceMeters,
    bool? isLoading,
    String? syncEndpoint,
    Vehicle? vehicle,
    List<Vehicle>? vehicles,
    bool? isLoadingVehicles,
    Object? lastVehicleError = _unchanged,
    bool? isSyncing,
    Object? lastSyncError = _unchanged,
  }) {
    return VehicleTrackingState(
      enabled: enabled ?? this.enabled,
      points: points ?? this.points,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isLoading: isLoading ?? this.isLoading,
      syncEndpoint: syncEndpoint ?? this.syncEndpoint,
      vehicle: vehicle ?? this.vehicle,
      vehicles: vehicles ?? this.vehicles,
      isLoadingVehicles: isLoadingVehicles ?? this.isLoadingVehicles,
      lastVehicleError: identical(lastVehicleError, _unchanged)
          ? this.lastVehicleError
          : lastVehicleError as String?,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncError: identical(lastSyncError, _unchanged)
          ? this.lastSyncError
          : lastSyncError as String?,
    );
  }

  static const _unchanged = Object();
}

final vehicleTrackingProvider =
    StateNotifierProvider<VehicleTrackingNotifier, VehicleTrackingState>((ref) {
      // Resolve dependencies from get_it rather than constructing inline.
      final auth = getIt<KeycloakAuthRepository>();
      final apiClient = getIt<VehicleApiClient>();
      final store = getIt<VehicleTrackingStoreService>();
      // Location capture and server sync are owned exclusively by the native
      // background service (offline-first: it durably records to SQLite
      // regardless of connectivity, then uploads opportunistically). Flutter
      // only reads that same store to reflect state in the UI — it does not
      // poll [currentLocationProvider] or sync independently, which would
      // otherwise race with native on the shared database and double-upload
      // points to the server.
      return VehicleTrackingNotifier(
        auth,
        apiClient: apiClient,
        store: store,
      );
    });

class VehicleTrackingNotifier extends StateNotifier<VehicleTrackingState> {
  VehicleTrackingNotifier(this.auth, {
    VehicleApiClient? apiClient,
    VehicleTrackingStoreService? store,
    bool loadPersisted = true,
  }) : _apiClient =
           apiClient ?? (throw ArgumentError('apiClient is required')),
       _store = store ?? VehicleTrackingStoreService(),
       super(const VehicleTrackingState(isLoading: true)) {
    if (loadPersisted) {
      unawaited(_load());
    } else {
      state = const VehicleTrackingState();
    }
    // Native owns capture and sync; this just keeps the UI's read-only view
    // of the shared offline-first store fresh between manual refreshes.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshIfStoreChanged(),
    );
  }

  final KeycloakAuthRepository auth;
  final VehicleApiClient _apiClient;
  final VehicleTrackingStoreService _store;
  late final Timer _refreshTimer;
  String? _storeStamp;

  Future<void> start() async {
    state = state.copyWith(
      enabled: true,
      isLoading: false,
      lastSyncError: null,
    );
    await _saveSettings();
    await _syncNativeConfig();
    final started = await _setNativeBackgroundTracking(true);
    if (!started && mounted) {
      // Native refused (most often: location permission not granted). Roll the
      // toggle back so the UI reflects reality.
      state = state.copyWith(
        enabled: false,
        lastSyncError: 'Location permission is required to track this vehicle.',
      );
      await _saveSettings();
      return;
    }
    unawaited(syncNow());
  }

  Future<void> stop() async {
    state = state.copyWith(enabled: false, isLoading: false);
    await _saveSettings();
    await _syncNativeConfig();
    await _setNativeBackgroundTracking(false);
  }

  Future<void> clear() async {
    state = state.copyWith(
      points: const [],
      distanceMeters: 0,
      isLoading: false,
      lastSyncError: null,
    );
    await _store.clear();
  }

  Future<void> setSyncEndpoint(String endpoint) async {
    state = state.copyWith(syncEndpoint: endpoint.trim(), lastSyncError: null);
    await _saveSettings();
    await _syncNativeConfig();
    unawaited(syncNow());
  }

  Future<void> saveVehicleProfile(Vehicle vehicle) async {
    state = state.copyWith(isLoadingVehicles: true, lastVehicleError: null);
    try {
      final saved = await _apiClient.saveVehicle(
        endpoint: state.syncEndpoint,
        vehicle: vehicle,
      );
      final vehicles = _upsertVehicle(state.vehicles, saved);
      state = state.copyWith(
        vehicles: vehicles,
        vehicle: saved,
        isLoadingVehicles: false,
        lastVehicleError: null,
      );
      await _store.saveVehicle(saved);
      await _syncNativeConfig();
    } catch (error) {
      state = state.copyWith(
        isLoadingVehicles: false,
        lastVehicleError: error.toString(),
      );
    }
  }

  Future<void> loadVehicles() async {
    state = state.copyWith(isLoadingVehicles: true, lastVehicleError: null);
    try {
      final vehicles = await _apiClient.fetchVehicles(
        endpoint: state.syncEndpoint,
      );
      state = state.copyWith(
        vehicles: vehicles,
        isLoadingVehicles: false,
        lastVehicleError: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingVehicles: false,
        lastVehicleError: error.toString(),
      );
    }
  }

  Future<void> assignVehicle(Vehicle vehicle) async {
    state = state.copyWith(isLoadingVehicles: true, lastVehicleError: null);
    try {
      state = state.copyWith(
        vehicle: vehicle,
        isLoadingVehicles: false,
        lastVehicleError: null,
      );
      await _store.saveVehicle(vehicle);
      await _syncNativeConfig();
    } catch (error) {
      state = state.copyWith(
        isLoadingVehicles: false,
        lastVehicleError: error.toString(),
      );
    }
  }

  /// Nudges the native background service to attempt an upload now, then
  /// refreshes this read-only view from the shared offline-first store.
  ///
  /// Flutter never captures points or uploads them itself — see the
  /// [vehicleTrackingProvider] definition for why. Points are already
  /// durably stored locally by native regardless of connectivity; this only
  /// requests an earlier attempt than native's next periodic cycle. If the
  /// native service isn't running (or this runs on a test/non-Android
  /// platform), the call is a no-op and the periodic refresh timer still
  /// picks up whatever native eventually syncs.
  Future<void> syncNow() async {
    if (!mounted || state.isSyncing) return;
    state = state.copyWith(isSyncing: true, lastSyncError: null);
    try {
      await NativeBridge.call<bool>('syncVehicleTrackingNow');
    } catch (e) {
      AppLogger.instance.d('Native sync nudge failed', tag: 'TRACKING', error: e);
    }
    // Give native's async HTTP batch a brief window before reading back.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _refreshFromStore(isSyncing: false);
  }

  Future<void> _load() async {
    try {
      final snapshot = await _store.load();
      final points = _dedupe(snapshot.points);
      if (!mounted) return;
      state = VehicleTrackingState(
        enabled: snapshot.enabled,
        points: points,
        distanceMeters: _calculateDistance(points),
        syncEndpoint: snapshot.syncEndpoint,
        vehicle: snapshot.vehicle,
        vehicles: snapshot.vehicle.hasData ? [snapshot.vehicle] : const [],
      );
      if (snapshot.enabled) await _setNativeBackgroundTracking(true);
      await _syncNativeConfig();
      unawaited(syncNow());
    } catch (e) {
      AppLogger.instance.w('Vehicle tracking initialisation failed', tag: 'TRACKING', error: e);
      if (mounted) state = const VehicleTrackingState();
    }
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;
    final snapshot = state;
    await _store.saveSettings(
      enabled: snapshot.enabled,
      syncEndpoint: snapshot.syncEndpoint,
    );
  }

  /// Periodic poll: reload only when native has written to the store since
  /// the last load, so an idle head unit does not re-read and re-publish
  /// every stored point (rebuilding all listeners) every 10 seconds.
  Future<void> _refreshIfStoreChanged() async {
    try {
      final stamp = await _store.changeStamp();
      if (stamp == _storeStamp) return;
      await _refreshFromStore();
    } catch (e) {
      AppLogger.instance.d('Tracking store poll failed', tag: 'TRACKING', error: e);
    }
  }

  Future<void> _refreshFromStore({
    bool? isSyncing,
    Object? lastSyncError = VehicleTrackingState._unchanged,
  }) async {
    final stamp = await _store.changeStamp();
    final snapshot = await _store.load();
    if (!mounted) return;
    _storeStamp = stamp;
    final points = _dedupe(snapshot.points);
    state = state.copyWith(
      enabled: snapshot.enabled,
      syncEndpoint: snapshot.syncEndpoint,
      vehicle: snapshot.vehicle,
      points: points,
      distanceMeters: _calculateDistance(points),
      isLoading: false,
      isSyncing: isSyncing,
      lastSyncError: lastSyncError,
    );
  }

  /// Returns whether the native side accepted the request. `false` when the
  /// foreground service could not be started (e.g. location permission missing).
  Future<bool> _setNativeBackgroundTracking(bool enabled) async {
    try {
      final ok = await NativeBridge.call<bool>(
        enabled ? 'startVehicleTrackingService' : 'stopVehicleTrackingService',
      );
      return ok ?? false;
    } catch (e) {
      // Tests and non-Android platforms do not have the native channel — treat
      // the toggle as a no-op success there.
      AppLogger.instance.d('Native background tracking toggle failed', tag: 'TRACKING', error: e);
      return true;
    }
  }

  /// Builds the exact POST URL the native background service should hit for
  /// this device's tracking points, so native never has to know the vehicle
  /// service's URL-shaping rules.
  ///
  /// Uploads go to `POST /public-api/v1/devices/me/tracking-points` under
  /// device-assertion auth (native mints it); the server derives the vehicle
  /// from the device link. Empty until a vehicle is assigned, so native does
  /// not upload for a device that is not linked yet.
  String _trackingPointsUrl() {
    if (state.vehicle.id.isEmpty) return '';
    final base = ApiConfig.vehicleServicePublicApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/devices/me/tracking-points';
  }

  Future<void> _syncNativeConfig() async {
    try {
      await NativeBridge.call<bool>('updateVehicleTrackingSyncConfig', {
        'trackingPointsUrl': _trackingPointsUrl(),
      });
    } catch (e) {
      // Tests and non-Android platforms do not have the native channel.
      AppLogger.instance.d('Native sync config update failed', tag: 'TRACKING', error: e);
    }
  }

  static List<VehicleTrackPoint> _dedupe(List<VehicleTrackPoint> points) {
    final byId = <String, VehicleTrackPoint>{};
    for (final point in points) {
      byId[point.id] = point;
    }
    return byId.values.toList(growable: false)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static double _calculateDistance(List<VehicleTrackPoint> points) {
    if (points.length < 2) return 0;
    var distance = 0.0;
    for (var i = 1; i < points.length; i++) {
      distance += points[i - 1].distanceTo(points[i]);
    }
    return distance;
  }

  static List<Vehicle> _upsertVehicle(
    List<Vehicle> vehicles,
    Vehicle vehicle,
  ) {
    final updated = [...vehicles];
    final index = updated.indexWhere(
      (item) => item.id.isNotEmpty && item.id == vehicle.id,
    );
    if (index >= 0) {
      updated[index] = vehicle;
    } else {
      updated.add(vehicle);
    }
    return updated;
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }
}
