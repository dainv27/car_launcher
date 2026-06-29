import 'dart:convert';

import 'package:car_launcher/core/api/api_config.dart';
import 'package:car_launcher/core/api/url_utils.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/services/device_info_service.dart';
import 'package:car_launcher/features/vehicle/domain/device.dart';
import 'package:http/http.dart' as http;

class DeviceService {
  DeviceService({required http.Client httpClient}) : this._(httpClient);

  DeviceService._(this._httpClient);

  final http.Client _httpClient;

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
    if (deviceInfo.id.isEmpty) {
      AppLogger.instance.w('Device registration skipped — no stable device id derivable', tag: 'DEVICE');
      return;
    }

    final device = Device(
      id: deviceInfo.id,
      name: _buildDeviceName(deviceInfo),
      serialNumber: deviceInfo.serial,
      imei: deviceInfo.imei,
      model: deviceInfo.model,
      firmwareVersion: deviceInfo.androidVersion,
      metadata: deviceInfo.toMap(),
    );

    await createDevice(endpoint: '', device: device);
    AppLogger.instance.i('Device registered on first install: ${deviceInfo.id}', tag: 'DEVICE');
  }

  /// Builds a human-readable device name from manufacturer and model.
  static String _buildDeviceName(DeviceInfo deviceInfo) {
    return [
      deviceInfo.manufacturer,
      deviceInfo.model,
    ].where((v) => v.isNotEmpty && v.toLowerCase() != 'unknown').join(' ').trim();
  }
}
