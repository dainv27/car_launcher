import 'dart:convert';

import 'package:car_launcher/core/api/api_response.dart';
import 'package:car_launcher/core/api/url_utils.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper over the vehicle-service `alert-client` endpoints:
/// speeding / idle alert rules and the alerts they raise. Owner-JWT
/// `client-api/v1`.
class AlertApiClient {
  AlertApiClient({required this._httpClient});

  final http.Client _httpClient;

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  // ---- Rules ---------------------------------------------------------------

  /// `GET /client-api/v1/alert-rules`
  Future<List<Map<String, dynamic>>> listRules({
    required String endpoint,
    String? vehicleId,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
    };
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(endpoint, 'alert-rules', queryParameters: query),
    );
    ApiResponse.ensureOk(res, 'List alert rules');
    return ApiResponse.items(res.body);
  }

  /// `POST /client-api/v1/alert-rules`
  Future<Map<String, dynamic>> createRule({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final res = await _httpClient.post(
      UrlUtils.vehicleUri(endpoint, 'alert-rules'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    ApiResponse.ensureOk(res, 'Create alert rule');
    return ApiResponse.object(res.body, key: 'rule');
  }

  /// `PATCH /client-api/v1/alert-rules/{ruleId}`
  Future<Map<String, dynamic>> updateRule({
    required String endpoint,
    required String ruleId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _httpClient.patch(
      UrlUtils.vehicleUri(endpoint, 'alert-rules/$ruleId'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    ApiResponse.ensureOk(res, 'Update alert rule');
    return ApiResponse.object(res.body, key: 'rule');
  }

  /// `DELETE /client-api/v1/alert-rules/{ruleId}`
  Future<void> deleteRule({
    required String endpoint,
    required String ruleId,
  }) async {
    final res = await _httpClient.delete(
      UrlUtils.vehicleUri(endpoint, 'alert-rules/$ruleId'),
    );
    ApiResponse.ensureOk(res, 'Delete alert rule');
  }

  // ---- Raised alerts -----------------------------------------------------

  /// `GET /client-api/v1/alerts`
  Future<List<Map<String, dynamic>>> listAlerts({
    required String endpoint,
    String? vehicleId,
    String? type,
    String? status,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      if (type != null && type.isNotEmpty) 'type': type,
      if (status != null && status.isNotEmpty) 'status': status,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(endpoint, 'alerts', queryParameters: query),
    );
    ApiResponse.ensureOk(res, 'List alerts');
    return ApiResponse.items(res.body);
  }

  /// `POST /client-api/v1/alerts/{alertId}/resolve`
  Future<Map<String, dynamic>> resolveAlert({
    required String endpoint,
    required String alertId,
  }) async {
    final res = await _httpClient.post(
      UrlUtils.vehicleUri(endpoint, 'alerts/$alertId/resolve'),
      headers: _jsonHeaders,
    );
    ApiResponse.ensureOk(res, 'Resolve alert');
    return ApiResponse.object(res.body, key: 'alert');
  }
}
