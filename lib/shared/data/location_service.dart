import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:car_launcher/core/api/api_config.dart';
import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';
import 'package:car_launcher/features/vehicle/domain/device.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/services/device_info_service.dart';
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
    this.year = '',
  });

  final String vehicleId;
  final String plateNumber;
  final String name;
  final String make;
  final String model;
  final String year;

  bool get hasData =>
      vehicleId.isNotEmpty ||
      plateNumber.isNotEmpty ||
      name.isNotEmpty ||
      make.isNotEmpty ||
      model.isNotEmpty ||
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
    String? year,
  }) {
    return VehicleProfile(
      vehicleId: vehicleId ?? this.vehicleId,
      plateNumber: plateNumber ?? this.plateNumber,
      name: name ?? this.name,
      make: make ?? this.make,
      model: model ?? this.model,
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
      year: json['year'] as String? ?? metadataYear,
    );
  }

  Map<String, dynamic> toJson() => {
    if (vehicleId.isNotEmpty) 'id': vehicleId,
    'vehicleId': vehicleId,
    'plateNumber': plateNumber,
    'name': name,
    'make': make,
    'model': model,
    'year': year,
  };

  Map<String, dynamic> toRegistrationJson() => {
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

class VehicleTrackingSyncClient {
  VehicleTrackingSyncClient({required http.Client httpClient})
    : this._(httpClient);

  VehicleTrackingSyncClient._(this._httpClient);

  final http.Client _httpClient;

  Future<void> sync({
    required String endpoint,
    required List<VehicleTrackPoint> points,
    VehicleProfile vehicle = const VehicleProfile(),
  }) async {
    if (vehicle.vehicleId.isEmpty) {
      throw StateError('Tracking sync requires assigned vehicle');
    }

    final url = _vehicleUri(
      endpoint,
      'vehicles/${vehicle.vehicleId}/tracking-points',
    );
    for (final point in points) {
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(point.toVehicleServiceJson()),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Tracking sync failed: HTTP ${response.statusCode}');
      }
    }
  }

  /// Fetch the latest tracking point for a vehicle.
  /// Returns null if the server responds with 204 No Content.
  Future<TrackingPoint?> getLatestTrackingPoint({
    required String endpoint,
    required String vehicleId,
  }) async {
    final response = await _httpClient.get(
      _vehicleUri(endpoint, 'vehicles/$vehicleId/tracking-points/latest'),
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

  /// Fetch a paginated list of tracking points for a vehicle.
  Future<List<TrackingPoint>> listTrackingPoints({
    required String endpoint,
    required String vehicleId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (from != null) queryParams['from'] = from.toUtc().toIso8601String();
    if (to != null) queryParams['to'] = to.toUtc().toIso8601String();
    final response = await _httpClient.get(
      _vehicleUri(
        endpoint,
        'vehicles/$vehicleId/tracking-points',
        queryParameters: queryParams,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Tracking points list failed: HTTP ${response.statusCode}',
      );
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
      _vehicleUri(
        endpoint,
        'vehicles',
        queryParameters: const {'page': '0', 'size': '10'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Vehicle list failed: HTTP ${response.statusCode}');
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
      _vehicleUri(endpoint, 'vehicles/$id'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Vehicle get failed: HTTP ${response.statusCode}');
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
    final response = await _httpClient.patch(
      _vehicleUri(endpoint, 'vehicles/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(vehicle.toRegistrationJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Vehicle update failed: HTTP ${response.statusCode}');
    }
    if (response.body.trim().isEmpty) return vehicle;
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['vehicle'];
      if (raw is Map<String, dynamic>) {
        return VehicleProfile.fromJson(raw);
      }
      return VehicleProfile.fromJson(decoded);
    }
    return vehicle;
  }

  Future<VehicleProfile> saveVehicle({
    required String endpoint,
    required VehicleProfile vehicle,
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    final response = await _httpClient.post(
      _vehicleUri(endpoint, 'vehicles'),
      body: jsonEncode(vehicle.toRegistrationJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Vehicle save failed: HTTP ${response.statusCode}');
    }
    if (response.body.trim().isEmpty) {
      final saved = vehicle;
      return saved;
    }
    final decoded = jsonDecode(response.body);
    VehicleProfile saved = vehicle;
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['vehicle'];
      if (raw is Map<String, dynamic>) {
        saved = VehicleProfile.fromJson(raw);
      } else {
        saved = VehicleProfile.fromJson(decoded);
      }
    }
    return saved;
  }

  Future<List<Map<String, dynamic>>> listDevices({
    required String endpoint,
    String? vehicleId,
  }) async {
    final queryParams = <String, String>{};
    if (vehicleId != null && vehicleId.isNotEmpty) {
      queryParams['vehicleId'] = vehicleId;
    }
    final uri = _vehicleUri(
      endpoint,
      'devices',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Device list failed: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    final raw = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['devices'] ?? decoded['content'] ?? decoded['items']
        : null;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Device> getDevice({
    required String endpoint,
    required String id,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${ApiConfig.vehicleServiceClientApiBaseUrl}/devices/$id'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Device get failed: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['device'];
      if (raw is Map<String, dynamic>) {
        return Device.fromJson(raw);
      }
      return Device.fromJson(decoded);
    }
    throw StateError('Device get failed: unexpected response shape');
  }

  Future<Device> createDevice({
    required String endpoint,
    required Device device,
  }) async {
    final deviceId = device.id;
    if (deviceId.isNotEmpty) {
      final getResponse = await _httpClient.get(
        _vehicleUri(endpoint, 'devices/$deviceId'),
      );
      if (getResponse.statusCode >= 200 && getResponse.statusCode < 300) {
        // Already registered — return the existing device
        final decoded = jsonDecode(getResponse.body);
        if (decoded is Map<String, dynamic>) {
          final raw = decoded['device'];
          if (raw is Map<String, dynamic>) {
            return Device.fromJson(raw);
          }
          return Device.fromJson(decoded);
        }
      }
    }
    final response = await _httpClient.post(
      _vehicleUri(endpoint, 'devices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(device.toCreateJson()),
    );
    if (response.statusCode == 409) {
      // Already exists — fetch it
      if (deviceId.isNotEmpty) {
        return getDevice(endpoint: endpoint, id: deviceId);
      }
      return device;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Device create failed: HTTP ${response.statusCode}');
    }
    if (response.body.trim().isEmpty) return device;
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['device'];
      if (raw is Map<String, dynamic>) {
        return Device.fromJson(raw);
      }
      return Device.fromJson(decoded);
    }
    return device;
  }


  /// Ensures this device is registered on the backend.
  ///
  /// Retrieves device info from the native layer, derives a stable device ID,
  /// and registers it via `POST /devices` if it does not already exist.
  /// Uses the same idempotency logic as [createDevice] (GET-then-POST with
  /// 409 conflict handling).
  Future<void> ensureDeviceRegistered() async {
    final deviceInfoService = DeviceInfoService.instance;
    final deviceInfo = await deviceInfoService.getInfo();
    if (deviceInfo == null) {
      AppLogger.instance.w('Device registration skipped — no device info available', tag: 'DEVICE');
      return;
    }
    final deviceId = deviceInfoService.deviceId(deviceInfo);
    if (deviceId.isEmpty) {
      AppLogger.instance.w('Device registration skipped — no stable device id derivable', tag: 'DEVICE');
      return;
    }

    final device = Device(
      id: deviceId,
      name: _buildDeviceName(deviceInfo),
      serialNumber: deviceInfo.serial,
      model: deviceInfo.model,
      metadata: deviceInfo.toMap(),
    );

    await createDevice(endpoint: '', device: device);
    AppLogger.instance.i('Device registered on first install: $deviceId', tag: 'DEVICE');
  }

  /// Builds a human-readable device name from manufacturer and model.
  static String _buildDeviceName(DeviceInfo deviceInfo) {
    return [deviceInfo.manufacturer, deviceInfo.model]
        .where((v) => v.isNotEmpty && v.toLowerCase() != 'unknown')
        .join(' ')
        .trim();
  }

  Uri _vehicleUri(
    String? endpoint,
    String relativePath, {
    Map<String, String>? queryParameters,
  }) {
    final base = _vehicleServiceBase(endpoint ?? '');
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        ...relativePath.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: queryParameters,
    );
  }

  Uri _vehicleServiceBase(String endpoint) {
    if (endpoint.trim().isEmpty) {
      return Uri.parse(ApiConfig.vehicleServiceClientApiBaseUrl);
    }
    final uri = Uri.parse(endpoint.trim());
    final segments = uri.pathSegments;
    final serviceIndex = segments.indexOf('vehicle-service');
    if (serviceIndex < 0) return uri;

    final versionIndex = segments.indexOf('v1', serviceIndex);
    final pathSegments = versionIndex < 0
        ? [...segments.take(serviceIndex + 1), 'client-api', 'v1']
        : segments.take(versionIndex + 1).toList(growable: false);

    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: pathSegments,
    );
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
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: syncClient,
        store: store,
      );
      ref.listen<AsyncValue<LocationInfo?>>(currentLocationProvider, (
        previous,
        next,
      ) {
        final location = next.valueOrNull;
        if (location != null) notifier.recordLocation(location);
      });
      return notifier;
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
    this.syncBatchSize = _defaultSyncBatchSize,
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
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
  }

  static const _maxPoints = 1000;
  static const _minimumDistanceMeters = 5.0;
  static const _defaultSyncBatchSize = 100;

  final KeycloakAuthRepository auth;
  final VehicleTrackingSyncClient _syncClient;
  final VehicleTrackingStoreService _store;
  final int syncBatchSize;
  late final Timer _syncTimer;
  bool _syncAgainRequested = false;

  Future<void> start() async {
    state = state.copyWith(
      enabled: true,
      isLoading: false,
      lastSyncError: null,
    );
    await _saveSettings();
    await _syncNativeConfig(() => auth.accessToken());
    await _setNativeBackgroundTracking(true);
    unawaited(syncNow());
  }

  Future<void> stop() async {
    state = state.copyWith(enabled: false, isLoading: false);
    await _saveSettings();
    await _syncNativeConfig(() => auth.accessToken(), clearToken: true);
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
    await _syncNativeConfig(() => auth.accessToken());
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
      await _syncNativeConfig(() => auth.accessToken());
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
      final deviceInfo = await _deviceInfo();
      state = state.copyWith(
        vehicle: vehicle,
        isLoadingVehicles: false,
        lastVehicleError: null,
      );
      await _store.saveVehicleProfile(vehicle);
      await _syncNativeConfig(() => auth.accessToken());
    } catch (error) {
      state = state.copyWith(
        isLoadingVehicles: false,
        lastVehicleError: error.toString(),
      );
    }
  }

  void recordLocation(LocationInfo location, {DateTime? timestamp}) {
    if (!mounted || !state.enabled) return;

    final point = VehicleTrackPoint.fromLocation(
      location,
      timestamp: timestamp,
    );
    final previous = state.lastPoint;
    if (previous != null &&
        previous.distanceTo(point) < _minimumDistanceMeters) {
      return;
    }

    final updatedPoints = _dedupe([...state.points, point]);
    final trimmedPoints = updatedPoints.length > _maxPoints
        ? updatedPoints.sublist(updatedPoints.length - _maxPoints)
        : updatedPoints;
    state = state.copyWith(
      points: trimmedPoints,
      distanceMeters: _calculateDistance(trimmedPoints),
      isLoading: false,
      lastSyncError: null,
    );
    unawaited(_store.appendPending(point).then((_) => syncNow()));
  }

  Future<void> syncNow() async {
    if (mounted && state.isSyncing) {
      _syncAgainRequested = true;
      return;
    }
    if (!mounted || state.isSyncing || state.vehicle.vehicleId.isEmpty) {
      return;
    }
    state = state.copyWith(isSyncing: true, lastSyncError: null);

    final online = await _hasValidatedInternet();
    if (!online || !mounted || state.vehicle.vehicleId.isEmpty) {
      if (mounted) state = state.copyWith(isSyncing: false);
      return;
    }

    try {
      while (mounted) {
        final pending = await _store.readPending();
        if (pending.isEmpty) break;

        final batchSize = syncBatchSize.clamp(1, pending.length).toInt();
        final batch = pending.take(batchSize).toList(growable: false);
        await _syncClient.sync(
          endpoint: state.syncEndpoint,
          points: batch,
          vehicle: state.vehicle,
        );
        if (!mounted) return;

        final syncedAt = DateTime.now().toUtc();
        final syncedIds = batch.map((point) => point.id).toSet();
        await _store.markSynced(syncedIds, syncedAt);
      }

      await _refreshFromStore(isSyncing: false, lastSyncError: null);
      if (mounted && _syncAgainRequested) {
        _syncAgainRequested = false;
        unawaited(syncNow());
      }
    } catch (error) {
      if (!mounted) return;
      await _refreshFromStore(
        isSyncing: false,
        lastSyncError: error.toString(),
      );
    }
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
      await _syncNativeConfig(() => auth.accessToken());
      unawaited(syncNow());
    } catch (_) {
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

  Future<void> _refreshFromStore({
    bool? isSyncing,
    Object? lastSyncError = VehicleTrackingState._unchanged,
  }) async {
    final snapshot = await _store.load();
    if (!mounted) return;
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

  Future<void> _setNativeBackgroundTracking(bool enabled) async {
    try {
      await NativeBridge.call<bool>(
        enabled ? 'startVehicleTrackingService' : 'stopVehicleTrackingService',
      );
    } catch (_) {
      // Tests and non-Android platforms do not have the native channel.
    }
  }

  Future<void> _syncNativeConfig(Future<String?> Function() accessToken, {bool clearToken = false}) async {
    try {
      final token = clearToken ? '' : await accessToken() ?? '';
      await NativeBridge.call<bool>('updateVehicleTrackingSyncConfig', {
        'syncEndpoint': state.syncEndpoint,
        'accessToken': token,
        'vehicle': state.vehicle.toJson(),
      });
    } catch (_) {
      // Tests and non-Android platforms do not have the native channel.
    }
  }

  Future<bool> _hasValidatedInternet() async {
    try {
      final status = await NativeBridge.call<Map<dynamic, dynamic>>(
        'getConnectivityStatus',
      );
      return status?['validated'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _deviceInfo() async {
    try {
      final raw = await NativeBridge.call<Map<dynamic, dynamic>>(
        'getDeviceInfo',
      );
      if (raw == null) return const {};
      return raw.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
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
    _syncTimer.cancel();
    super.dispose();
  }
}
