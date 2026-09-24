import 'dart:convert';

import 'package:car_launcher/core/api/url_utils.dart';
import 'package:car_launcher/core/auth/device_identity_service.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:http/http.dart' as http;

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

/// Thin HTTP wrapper over the vehicle-service `client-api` vehicle CRUD
/// endpoints. The injected [http.Client] is the app's `AuthInterceptorClient`
/// and adds the bearer token.
class VehicleApiClient {
  VehicleApiClient({
    required this._httpClient,
    DeviceIdentityService? identity,
  }) : _identity = identity ?? DeviceIdentityService.instance;

  final http.Client _httpClient;
  final DeviceIdentityService _identity;

  /// `POST/PATCH /client-api/v1/vehicles` require the enrolled (attested) device
  /// id — it is what claims this device and links it to the vehicle. Fill it in
  /// from the native identity when the caller did not set one.
  Future<Vehicle> _withEnrolledDeviceId(Vehicle vehicle) async {
    if (vehicle.deviceId.isNotEmpty) return vehicle;
    try {
      final identity = await _identity.getIdentity();
      if (identity.deviceId.isEmpty) return vehicle;
      return vehicle.copyWith(deviceId: identity.deviceId);
    } catch (error) {
      AppLogger.instance.w(
        'Could not resolve enrolled device id for vehicle registration',
        tag: 'VEHICLE',
        error: error,
      );
      return vehicle;
    }
  }

  /// `GET /client-api/v1/vehicles?page=0&size=10`
  Future<List<Vehicle>> fetchVehicles({required String endpoint}) async {
    final response = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        'vehicles',
        queryParameters: const {'page': '0', 'size': '10'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VehicleServiceException.fromResponse(
        response,
        'Could not load vehicles',
      );
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
        .map(Vehicle.fromJson)
        .toList(growable: false);
  }

  /// `GET /client-api/v1/vehicles/:id`
  Future<Vehicle> getVehicle({
    required String endpoint,
    required String id,
  }) async {
    final response = await _httpClient.get(
      UrlUtils.vehicleUri(endpoint, 'vehicles/$id'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VehicleServiceException.fromResponse(
        response,
        'Could not load the vehicle',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['vehicle'];
      if (raw is Map<String, dynamic>) {
        return Vehicle.fromJson(raw);
      }
      return Vehicle.fromJson(decoded);
    }
    throw StateError('Vehicle get failed: unexpected response shape');
  }

  /// `PATCH /client-api/v1/vehicles/:id`
  Future<Vehicle> updateVehicle({
    required String endpoint,
    required String id,
    required Vehicle vehicle,
  }) async {
    final withDevice = await _withEnrolledDeviceId(vehicle);
    final response = await _httpClient.patch(
      UrlUtils.vehicleUri(endpoint, 'vehicles/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(withDevice.toPatchJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VehicleServiceException.fromResponse(
        response,
        'Could not update the vehicle',
      );
    }
    if (response.body.trim().isEmpty) return withDevice;
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['vehicle'];
      if (raw is Map<String, dynamic>) {
        return Vehicle.fromJson(raw);
      }
      return Vehicle.fromJson(decoded);
    }
    return withDevice;
  }

  /// `POST /client-api/v1/vehicles`
  Future<Vehicle> saveVehicle({
    required String endpoint,
    required Vehicle vehicle,
  }) async {
    final withDevice = await _withEnrolledDeviceId(vehicle);
    final response = await _httpClient.post(
      UrlUtils.vehicleUri(endpoint, 'vehicles'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(withDevice.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.instance.w(
        'Vehicle save rejected: HTTP ${response.statusCode} — ${response.body}',
        tag: 'VEHICLE',
      );
      throw VehicleServiceException.fromResponse(
        response,
        'Could not register the vehicle',
      );
    }
    if (response.body.trim().isEmpty) {
      return withDevice;
    }
    final decoded = jsonDecode(response.body);
    Vehicle saved = withDevice;
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['vehicle'];
      if (raw is Map<String, dynamic>) {
        saved = Vehicle.fromJson(raw);
      } else {
        saved = Vehicle.fromJson(decoded);
      }
    }
    return saved.deviceId.isEmpty
        ? saved.copyWith(deviceId: withDevice.deviceId)
        : saved;
  }
}
