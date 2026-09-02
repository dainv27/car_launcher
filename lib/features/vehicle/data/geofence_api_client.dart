import 'dart:convert';

import 'package:car_launcher/core/api/api_response.dart';
import 'package:car_launcher/core/api/url_utils.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper over the vehicle-service `geofence-client` endpoints
/// (CRUD + transition events). Owner-JWT `client-api/v1`.
class GeofenceApiClient {
  GeofenceApiClient({required this._httpClient});

  final http.Client _httpClient;

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  /// `GET /client-api/v1/geofences`
  Future<List<Map<String, dynamic>>> listGeofences({
    required String endpoint,
    String? vehicleId,
    bool? active,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      if (active != null) 'active': '$active',
    };
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(endpoint, 'geofences', queryParameters: query),
    );
    ApiResponse.ensureOk(res, 'List geofences');
    return ApiResponse.items(res.body);
  }

  /// `POST /client-api/v1/geofences`
  Future<Map<String, dynamic>> createGeofence({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final res = await _httpClient.post(
      UrlUtils.vehicleUri(endpoint, 'geofences'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    ApiResponse.ensureOk(res, 'Create geofence');
    return ApiResponse.object(res.body, key: 'geofence');
  }

  /// `PATCH /client-api/v1/geofences/{geofenceId}`
  Future<Map<String, dynamic>> updateGeofence({
    required String endpoint,
    required String geofenceId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _httpClient.patch(
      UrlUtils.vehicleUri(endpoint, 'geofences/$geofenceId'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    ApiResponse.ensureOk(res, 'Update geofence');
    return ApiResponse.object(res.body, key: 'geofence');
  }

  /// `DELETE /client-api/v1/geofences/{geofenceId}`
  Future<void> deleteGeofence({
    required String endpoint,
    required String geofenceId,
  }) async {
    final res = await _httpClient.delete(
      UrlUtils.vehicleUri(endpoint, 'geofences/$geofenceId'),
    );
    ApiResponse.ensureOk(res, 'Delete geofence');
  }

  /// `GET /client-api/v1/geofences/events`
  Future<List<Map<String, dynamic>>> listEvents({
    required String endpoint,
    String? vehicleId,
    String? geofenceId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      if (geofenceId != null && geofenceId.isNotEmpty) 'geofenceId': geofenceId,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(endpoint, 'geofences/events', queryParameters: query),
    );
    ApiResponse.ensureOk(res, 'List geofence events');
    return ApiResponse.items(res.body);
  }
}
