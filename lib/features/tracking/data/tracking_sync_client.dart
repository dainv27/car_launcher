import 'dart:convert';

import 'package:car_launcher/core/api/api_config.dart';
import 'package:car_launcher/core/api/url_utils.dart';
import 'package:car_launcher/core/auth/device_assertion_client.dart';
import 'package:car_launcher/features/tracking/domain/tracking_point.dart';
import 'package:car_launcher/features/tracking/domain/vehicle_track_point.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper over the vehicle-service tracking-point endpoints:
/// pushing points captured locally, and reading them back for the history
/// views. Vehicle CRUD lives separately in `VehicleApiClient`
/// (features/vehicle) — this client only ever touches tracking points.
class TrackingSyncClient {
  TrackingSyncClient({
    required this._httpClient,
    http.Client? pushClient,
    String? publicApiBaseUrl,
  }) : _pushClient = pushClient ?? DeviceAssertionClient(inner: http.Client()),
       _publicApiBaseUrl =
           (publicApiBaseUrl ?? ApiConfig.vehicleServicePublicApiBaseUrl)
               .replaceAll(RegExp(r'/+$'), '');

  final http.Client _httpClient;

  /// Device-assertion-authenticated client for the public tracking API.
  final http.Client _pushClient;
  final String _publicApiBaseUrl;

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
    Vehicle vehicle = const Vehicle(),
  }) async {
    if (vehicle.id.isEmpty) {
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
}
