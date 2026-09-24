import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:car_launcher/core/api/api_config.dart';
import 'package:car_launcher/core/api/url_utils.dart';
import 'package:car_launcher/core/auth/device_assertion_client.dart';
import 'package:car_launcher/core/auth/device_identity_service.dart';
import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/core/services/device_info_service.dart';
import 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'vehicle_tracking_store_service.dart';

class LocationInfo {
  const LocationInfo({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;

  factory LocationInfo.fromMap(Map<Object?, Object?> map) {
    return LocationInfo(
      displayName: map['displayName'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }
}

class VehicleTrackPoint {
  const VehicleTrackPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.displayName = '',
    this.syncedAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String displayName;
  final DateTime? syncedAt;

  bool get synced => syncedAt != null;

  factory VehicleTrackPoint.fromLocation(
    LocationInfo location, {
    DateTime? timestamp,
  }) {
    final capturedAt = timestamp ?? DateTime.now();
    return VehicleTrackPoint(
      id: _buildId(capturedAt, location.latitude, location.longitude),
      latitude: location.latitude,
      longitude: location.longitude,
      displayName: location.displayName,
      timestamp: capturedAt,
    );
  }

  factory VehicleTrackPoint.fromJson(Map<String, dynamic> json) {
    final timestamp =
        DateTime.tryParse(json['timestamp'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final latitude = (json['latitude'] as num).toDouble();
    final longitude = (json['longitude'] as num).toDouble();
    return VehicleTrackPoint(
      id: json['id'] as String? ?? _buildId(timestamp, latitude, longitude),
      latitude: latitude,
      longitude: longitude,
      displayName: json['displayName'] as String? ?? '',
      timestamp: timestamp,
      syncedAt: DateTime.tryParse(json['syncedAt'] as String? ?? ''),
    );
  }

  VehicleTrackPoint markSynced(DateTime value) => VehicleTrackPoint(
    id: id,
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    displayName: displayName,
    syncedAt: value,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'displayName': displayName,
    'timestamp': timestamp.toIso8601String(),
    if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
  };

  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'displayName': displayName,
    'timestamp': timestamp.toIso8601String(),
  };

  Map<String, dynamic> toVehicleServiceJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'eventTime': timestamp.toUtc().toIso8601String(),
    'metadata': {
      'clientPointId': id,
      if (displayName.isNotEmpty) 'displayName': displayName,
    },
  };

  double distanceTo(VehicleTrackPoint other) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _degToRad(latitude);
    final lat2 = _degToRad(other.latitude);
    final dLat = _degToRad(other.latitude - latitude);
    final dLon = _degToRad(other.longitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static String _buildId(
    DateTime timestamp,
    double latitude,
    double longitude,
  ) {
    return '${timestamp.toUtc().microsecondsSinceEpoch}_${latitude.toStringAsFixed(6)}_${longitude.toStringAsFixed(6)}';
  }

  static double _degToRad(double deg) => deg * math.pi / 180;
}

class VehicleProfile {
  const VehicleProfile({
    this.vehicleId = '',
    this.plateNumber = '',
    this.name = '',
    this.make = '',
    this.model = '',
    this.deviceId = '',
    this.year = '',
  });

  final String vehicleId;
  final String plateNumber;
  final String name;
  final String make;
  final String model;
  final String deviceId;
  final String year;

  bool get hasData =>
      vehicleId.isNotEmpty ||
      plateNumber.isNotEmpty ||
      name.isNotEmpty ||
      make.isNotEmpty ||
      model.isNotEmpty ||
      deviceId.isNotEmpty ||
      year.isNotEmpty;

  String get displayName {
    if (plateNumber.isNotEmpty) return plateNumber;
    if (name.isNotEmpty) return name;
    if (vehicleId.isNotEmpty) return vehicleId;
    return 'Not registered';
  }

  VehicleProfile copyWith({
    String? vehicleId,
    String? plateNumber,
    String? name,
    String? make,
    String? model,
    String? deviceId,
    String? year,
  }) {
    return VehicleProfile(
      vehicleId: vehicleId ?? this.vehicleId,
      plateNumber: plateNumber ?? this.plateNumber,
      name: name ?? this.name,
      make: make ?? this.make,
      model: model ?? this.model,
      deviceId: deviceId ?? this.deviceId,
      year: year ?? this.year,
    );
  }

  factory VehicleProfile.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    final metadataYear = metadata is Map<String, dynamic>
        ? metadata['year'] as String? ?? ''
        : '';
    return VehicleProfile(
      vehicleId: json['vehicleId'] as String? ?? json['id'] as String? ?? '',
      plateNumber: json['plateNumber'] as String? ?? '',
      name: json['name'] as String? ?? '',
      make: json['make'] as String? ?? json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      year: json['year'] as String? ?? metadataYear,
    );
  }

  Map<String, dynamic> toJson() => {
    if (vehicleId.isNotEmpty) 'id': vehicleId,
    'vehicleId': vehicleId,
    if (deviceId.isNotEmpty) 'deviceId': deviceId,
    'plateNumber': plateNumber,
    'name': name,
    'make': make,
    'model': model,
    'year': year,
  };

  Map<String, dynamic> toRegistrationJson() => {
    if (deviceId.isNotEmpty) 'deviceId': deviceId,
    'plateNumber': plateNumber,
    'name': name,
    'brand': make,
    'model': model,
    if (year.isNotEmpty) 'metadata': {'year': year},
  };
}

class VehicleTrackingState {
  const VehicleTrackingState({
    this.enabled = false,
    this.points = const [],
    this.distanceMeters = 0,
    this.isLoading = false,
    this.syncEndpoint = '',
    this.vehicle = const VehicleProfile(),
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
  final VehicleProfile vehicle;
  final List<VehicleProfile> vehicles;
  final bool isLoadingVehicles;
  final String? lastVehicleError;
  final bool isSyncing;
  final String? lastSyncError;

  VehicleTrackPoint? get lastPoint => points.isEmpty ? null : points.last;

  int get pointCount => points.length;

  int get pendingSyncCount => points.where((point) => !point.synced).length;

  bool get hasRoute => points.length > 1;

  bool get canSync => vehicle.vehicleId.isNotEmpty && pendingSyncCount > 0;

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
    VehicleProfile? vehicle,
    List<VehicleProfile>? vehicles,
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

/// A non-2xx answer from `vehicle-service`, carrying the server's own
/// human-readable `message` (localised by the backend) when it sent one.
class VehicleServiceException implements Exception {
  const VehicleServiceException(this.statusCode, this.message);

  /// Builds the exception from an error response, preferring the body's
  /// `message` over [fallback].
  factory VehicleServiceException.fromResponse(
    http.Response response,
    String fallback,
  ) {
    String? message;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final raw = decoded['message'];
        if (raw is String && raw.trim().isNotEmpty) message = raw.trim();
      }
    } catch (_) {
      // Not JSON (gateway error page, empty body) — use the fallback.
    }
    return VehicleServiceException(
      response.statusCode,
      message ?? '$fallback (HTTP ${response.statusCode})',
    );
  }

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class VehicleTrackingSyncClient {
  VehicleTrackingSyncClient({
    required this._httpClient,
    http.Client? pushClient,
    String? publicApiBaseUrl,
    DeviceIdentityService? identity,
  })  : _pushClient = pushClient ?? DeviceAssertionClient(inner: http.Client()),
        _identity = identity ?? DeviceIdentityService.instance,
        _publicApiBaseUrl =
            (publicApiBaseUrl ?? ApiConfig.vehicleServicePublicApiBaseUrl)
                .replaceAll(RegExp(r'/+$'), '');

  final http.Client _httpClient;

  /// Device-assertion-authenticated client for the public tracking API.
  final http.Client _pushClient;
  final DeviceIdentityService _identity;
  final String _publicApiBaseUrl;

  /// `POST/PATCH /client-api/v1/vehicles` require the enrolled (attested) device
  /// id — it is what claims this device and links it to the vehicle. Fill it in
  /// from the native identity when the caller did not set one.
  Future<VehicleProfile> _withEnrolledDeviceId(VehicleProfile vehicle) async {
    if (vehicle.deviceId.isNotEmpty) return vehicle;
    try {
      final identity = await _identity.getIdentity();
      if (identity.deviceId.isEmpty) return vehicle;
      return vehicle.copyWith(deviceId: identity.deviceId);
    } catch (error) {
      AppLogger.instance.w(
        'Could not resolve enrolled device id for vehicle registration',
        tag: 'TRACKING',
        error: error,
      );
      return vehicle;
    }
  }

  /// Pushes tracking points for *this* device via
  /// `POST /public-api/v1/devices/me/tracking-points` (device-assertion auth).
  /// The vehicle is derived server-side from the device link, so [endpoint] is
  /// unused here and [vehicle] only gates on a vehicle being assigned locally.
  ///
  /// A 409 means the device is enrolled but not yet linked to a vehicle — the
  /// points stay pending and this surfaces as a sync error, not a crash.
  Future<void> sync({
    required String endpoint,
    required List<VehicleTrackPoint> points,
    VehicleProfile vehicle = const VehicleProfile(),
  }) async {
    if (vehicle.vehicleId.isEmpty) {
      throw StateError('Tracking sync requires an assigned vehicle');
    }

    final url = Uri.parse('$_publicApiBaseUrl/devices/me/tracking-points');
    for (final point in points) {
      final response = await _pushClient.post(
        url,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(point.toVehicleServiceJson()),
      );
      if (response.statusCode == 409) {
        throw StateError(
          'Tracking sync rejected: device is not linked to a vehicle yet',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Tracking sync failed: HTTP ${response.statusCode}');
      }
    }
  }

  /// Fetch the latest tracking point for a device.
  /// Returns null if the server responds with 204 No Content.
  Future<TrackingPoint?> getLatestTrackingPoint({
    required String endpoint,
    required String deviceId,
  }) async {
    final response = await _httpClient.get(
      UrlUtils.vehicleUri(endpoint, 'devices/$deviceId/tracking-points/latest'),
    );
    if (response.statusCode == 204) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Latest tracking point fetch failed: HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return TrackingPoint.fromJson(decoded);
    }
    throw StateError('Latest tracking point fetch failed: unexpected shape');
  }

  /// Fetch a paginated list of tracking points for a device.
  Future<List<TrackingPoint>> listTrackingPoints({
    required String endpoint,
    required String deviceId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    return _listTrackingPoints(
      endpoint: endpoint,
      relativePath: 'devices/$deviceId/tracking-points',
      from: from,
      to: to,
      page: page,
      size: size,
      what: 'Tracking points list',
    );
  }

  /// Fetch the newest tracking point for a vehicle.
  ///
  /// Uses the current vehicle-scoped client API
  /// (`GET /client-api/v1/vehicles/{vehicleId}/tracking-points/latest`);
  /// returns null on 204 No Content.
  Future<TrackingPoint?> getLatestVehicleTrackingPoint({
    required String endpoint,
    required String vehicleId,
  }) async {
    final response = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        'vehicles/$vehicleId/tracking-points/latest',
      ),
    );
    if (response.statusCode == 204 || response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Latest tracking point fetch failed: HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return TrackingPoint.fromJson(decoded);
    }
    throw StateError('Latest tracking point fetch failed: unexpected shape');
  }

  /// Fetch a paginated list of tracking points for a vehicle.
  ///
  /// Uses the current vehicle-scoped client API
  /// (`GET /client-api/v1/vehicles/{vehicleId}/tracking-points`).
  Future<List<TrackingPoint>> listVehicleTrackingPoints({
    required String endpoint,
    required String vehicleId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    return _listTrackingPoints(
      endpoint: endpoint,
      relativePath: 'vehicles/$vehicleId/tracking-points',
      from: from,
      to: to,
      page: page,
      size: size,
      what: 'Vehicle tracking points list',
    );
  }

  Future<List<TrackingPoint>> _listTrackingPoints({
    required String endpoint,
    required String relativePath,
    required DateTime? from,
    required DateTime? to,
    required int page,
    required int size,
    required String what,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (from != null) queryParams['from'] = from.toUtc().toIso8601String();
    if (to != null) queryParams['to'] = to.toUtc().toIso8601String();
    final response = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        relativePath,
        queryParameters: queryParams,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$what failed: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    final raw = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['content'] ??
              decoded['data'] ??
              decoded['items'] ??
              decoded['trackingPoints']
        : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TrackingPoint.fromJson)
        .toList(growable: false);
  }

  Future<List<VehicleProfile>> fetchVehicles({required String endpoint}) async {
    final response = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        'vehicles',
        queryParameters: const {'page': '0', 'size': '10'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VehicleServiceException.fromResponse(response, 'Could not load vehicles');
    }
    final decoded = jsonDecode(response.body);
    final rawVehicles = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['vehicles'] ??
              decoded['content'] ??
              decoded['data'] ??
              decoded['items']
        : null;
    if (rawVehicles is! List) return const [];
    return rawVehicles
        .whereType<Map<String, dynamic>>()
        .map(VehicleProfile.fromJson)
        .toList(growable: false);
  }

  Future<VehicleProfile> getVehicle({
    required String endpoint,
    required String id,
  }) async {
    final response = await _httpClient.get(
      UrlUtils.vehicleUri(endpoint, 'vehicles/$id'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VehicleServiceException.fromResponse(response, 'Could not load the vehicle');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['vehicle'];
      if (raw is Map<String, dynamic>) {
        return VehicleProfile.fromJson(raw);
      }
      return VehicleProfile.fromJson(decoded);
    }
    throw StateError('Vehicle get failed: unexpected response shape');
  }

  Future<VehicleProfile> updateVehicle({
    required String endpoint,
    required String id,
    required VehicleProfile vehicle,
  }) async {
    final withDevice = await _withEnrolledDeviceId(vehicle);
    final response = await _httpClient.patch(
      UrlUtils.vehicleUri(endpoint, 'vehicles/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(withDevice.toRegistrationJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VehicleServiceException.fromResponse(response, 'Could not update the vehicle');
    }
    if (response.body.trim().isEmpty) return withDevice;
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['vehicle'];
      if (raw is Map<String, dynamic>) {
        return VehicleProfile.fromJson(raw);
      }
      return VehicleProfile.fromJson(decoded);
    }
    return withDevice;
  }

  Future<VehicleProfile> saveVehicle({
    required String endpoint,
    required VehicleProfile vehicle,
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    final withDevice = await _withEnrolledDeviceId(vehicle);
    final response = await _httpClient.post(
      UrlUtils.vehicleUri(endpoint, 'vehicles'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(withDevice.toRegistrationJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.instance.w(
        'Vehicle save rejected: HTTP ${response.statusCode} — ${response.body}',
        tag: 'VEHICLE',
      );
      throw VehicleServiceException.fromResponse(response, 'Could not register the vehicle');
    }
    if (response.body.trim().isEmpty) {
      return withDevice;
    }
    final decoded = jsonDecode(response.body);
    VehicleProfile saved = withDevice;
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['vehicle'];
      if (raw is Map<String, dynamic>) {
        saved = VehicleProfile.fromJson(raw);
      } else {
        saved = VehicleProfile.fromJson(decoded);
      }
    }
    return saved.deviceId.isEmpty
        ? saved.copyWith(deviceId: withDevice.deviceId)
        : saved;
  }
}

final currentLocationProvider =
    StateNotifierProvider<LocationNotifier, AsyncValue<LocationInfo?>>((ref) {
      return LocationNotifier();
    });

final vehicleTrackingProvider =
    StateNotifierProvider<VehicleTrackingNotifier, VehicleTrackingState>((ref) {
      // Resolve dependencies from get_it rather than constructing inline.
      final auth = getIt<KeycloakAuthRepository>();
      final syncClient = getIt<VehicleTrackingSyncClient>();
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
        syncClient: syncClient,
        store: store,
      );
    });

class LocationNotifier extends StateNotifier<AsyncValue<LocationInfo?>> {
  LocationNotifier() : super(const AsyncValue.loading()) {
    refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  late final Timer _timer;
  bool _permissionRequested = false;
  int _requestGeneration = 0;

  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_requestGeneration;
    try {
      final raw = await NativeBridge.call<Map<Object?, Object?>>(
        'getCurrentLocationInfo',
      );
      if (!mounted || generation != _requestGeneration) return;
      if (raw == null || raw['status'] != 'ok') {
        if (raw?['status'] == 'permission_required' && !_permissionRequested) {
          _permissionRequested = true;
          await NativeBridge.call<bool>('requestLocationPermission');
          if (!mounted || generation != _requestGeneration) return;
          unawaited(
            Future<void>.delayed(const Duration(seconds: 4), () {
              if (mounted && generation == _requestGeneration) refresh();
            }),
          );
        }
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.data(LocationInfo.fromMap(raw));
    } catch (error, stackTrace) {
      if (mounted && generation == _requestGeneration) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    _timer.cancel();
    super.dispose();
  }
}

class VehicleTrackingNotifier extends StateNotifier<VehicleTrackingState> {
  VehicleTrackingNotifier(this.auth, {
    VehicleTrackingSyncClient? syncClient,
    VehicleTrackingStoreService? store,
    bool loadPersisted = true,
  }) : _syncClient =
           syncClient ?? (throw ArgumentError('syncClient is required')),
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
  final VehicleTrackingSyncClient _syncClient;
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

  Future<void> saveVehicleProfile(VehicleProfile vehicle) async {
    state = state.copyWith(isLoadingVehicles: true, lastVehicleError: null);
    try {
      final deviceInfo = await _deviceInfo();
      final saved = await _syncClient.saveVehicle(
        endpoint: state.syncEndpoint,
        vehicle: vehicle,
        deviceInfo: deviceInfo,
      );
      final vehicles = _upsertVehicle(state.vehicles, saved);
      state = state.copyWith(
        vehicles: vehicles,
        vehicle: saved,
        isLoadingVehicles: false,
        lastVehicleError: null,
      );
      await _store.saveVehicleProfile(saved);
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
      final vehicles = await _syncClient.fetchVehicles(
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

  Future<void> assignVehicle(VehicleProfile vehicle) async {
    state = state.copyWith(isLoadingVehicles: true, lastVehicleError: null);
    try {
      state = state.copyWith(
        vehicle: vehicle,
        isLoadingVehicles: false,
        lastVehicleError: null,
      );
      await _store.saveVehicleProfile(vehicle);
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
    if (state.vehicle.vehicleId.isEmpty) return '';
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

  Future<Map<String, dynamic>> _deviceInfo() async {
    try {
      final info = await DeviceInfoService.instance.fetchDeviceInfo();
      return info.toMap();
    } catch (e) {
      AppLogger.instance.d('Device info fetch failed', tag: 'TRACKING', error: e);
      return const {};
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

  static List<VehicleProfile> _upsertVehicle(
    List<VehicleProfile> vehicles,
    VehicleProfile vehicle,
  ) {
    final updated = [...vehicles];
    final index = updated.indexWhere(
      (item) =>
          item.vehicleId.isNotEmpty && item.vehicleId == vehicle.vehicleId,
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
