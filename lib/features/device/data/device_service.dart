import 'dart:convert';

import 'package:car_launcher/core/api/api_config.dart';
import 'package:car_launcher/core/api/url_utils.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/features/device/data/device_info_service.dart';
import 'package:car_launcher/features/device/data/device_enrollment_client.dart';
import 'package:car_launcher/features/device/domain/device.dart';
import 'package:http/http.dart' as http;

class DeviceService {
  DeviceService({
    required this._httpClient,
    DeviceEnrollmentClient? enrollmentClient,
  }) : _enrollmentClient = enrollmentClient ??
            DeviceEnrollmentClient(
              // Enrollment is attestation-authenticated, not Keycloak — use a
              // plain client so no bearer token is attached.
              httpClient: http.Client(),
              publicApiBaseUrl: ApiConfig.vehicleServicePublicApiBaseUrl,
            );

  final http.Client _httpClient;
  final DeviceEnrollmentClient _enrollmentClient;

  Future<List<Map<String, dynamic>>> listDevices({required String endpoint, String? vehicleId}) async {
    final queryParams = <String, String>{};
    if (vehicleId != null && vehicleId.isNotEmpty) {
      queryParams['vehicleId'] = vehicleId;
    }
    final uri = UrlUtils.vehicleUri(endpoint, 'devices', queryParameters: queryParams.isEmpty ? null : queryParams);
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

  Future<Device> getDevice({required String endpoint, required String id}) async {
    final response = await _httpClient.get(Uri.parse('${ApiConfig.vehicleServiceClientApiBaseUrl}/devices/$id'));
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

  Future<Device> createDevice({required String endpoint, required Device device}) async {
    final deviceId = device.id;
    if (deviceId.isNotEmpty) {
      final getResponse = await _httpClient.get(UrlUtils.vehicleUri(endpoint, 'devices/$deviceId'));
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
      UrlUtils.vehicleUri(endpoint, 'devices'),
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

  /// Enrolls this device with `vehicle-service` so it exists in the backend.
  ///
  /// Runs the SELF_SIGNED_PKI attestation handshake
  /// (`POST /public-api/v1/devices/enroll`) — no Keycloak session. The device
  /// is created *unclaimed*; a signed-in user links it to a vehicle later
  /// through the client API. Enrollment is idempotent, so this is safe to call
  /// on every launch; failures are logged and retried next launch.
  ///
  /// Returns the enrolled device, or `null` when device info is unavailable.
  Future<EnrolledDevice?> ensureDeviceRegistered() async {
    final deviceInfo = await DeviceInfoService.instance.getInfo();
    if (deviceInfo == null) {
      AppLogger.instance.w(
        'Device enrollment skipped — no device info available',
        tag: 'DEVICE',
      );
      return null;
    }

    final device = await _enrollmentClient.enroll(
      name: _buildDeviceName(deviceInfo),
      serialNumber: deviceInfo.serial,
      imei: deviceInfo.imei,
      model: deviceInfo.model,
      firmwareVersion: deviceInfo.androidVersion,
      metadata: deviceInfo.toMap(),
    );

    // Round-trip the per-install key: mint an X-Device-Assertion and read the
    // device back. Best-effort — a failure here does not undo enrollment.
    try {
      final self = await _enrollmentClient.getSelf();
      AppLogger.instance.i(
        'Device self-check OK: ${self.id} (claimed=${self.claimed})',
        tag: 'DEVICE',
      );
    } catch (error) {
      AppLogger.instance.w(
        'Device self-check failed after enrollment',
        tag: 'DEVICE',
        error: error,
      );
    }

    return device;
  }

  /// Builds a human-readable device name from manufacturer and model.
  static String _buildDeviceName(DeviceInfo deviceInfo) {
    return [
      deviceInfo.manufacturer,
      deviceInfo.model,
    ].where((v) => v.isNotEmpty && v.toLowerCase() != 'unknown').join(' ').trim();
  }
}
