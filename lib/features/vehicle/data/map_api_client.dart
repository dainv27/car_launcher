import 'package:car_launcher/core/api/api_response.dart';
import 'package:car_launcher/core/api/url_utils.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper over the vehicle-service map helpers:
/// simplified route polyline, reverse geocoding and bounding-box positions.
///
/// `reverse-geocode` / `snap-to-road` depend on an operator-configured
/// provider and answer `503` when it is not set — those methods return `null`
/// in that case so the UI can simply omit the feature.
class MapApiClient {
  MapApiClient({required this._httpClient});

  final http.Client _httpClient;

  /// `GET /client-api/v1/vehicles/{vehicleId}/tracking-points/route`
  Future<Map<String, dynamic>> getRoute({
    required String endpoint,
    required String vehicleId,
    DateTime? from,
    DateTime? to,
    double? toleranceMeters,
    int? maxPoints,
  }) async {
    final query = <String, String>{
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (toleranceMeters != null) 'toleranceMeters': '$toleranceMeters',
      if (maxPoints != null) 'maxPoints': '$maxPoints',
    };
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        'vehicles/$vehicleId/tracking-points/route',
        queryParameters: query.isEmpty ? null : query,
      ),
    );
    ApiResponse.ensureOk(res, 'Get route');
    return ApiResponse.object(res.body);
  }

  /// `GET /client-api/v1/tracking/reverse-geocode` — `null` when the provider
  /// is not configured (`503`).
  Future<Map<String, dynamic>?> reverseGeocode({
    required String endpoint,
    required double lat,
    required double lon,
  }) async {
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        'tracking/reverse-geocode',
        queryParameters: {'lat': '$lat', 'lon': '$lon'},
      ),
    );
    if (res.statusCode == 503) return null;
    ApiResponse.ensureOk(res, 'Reverse geocode');
    return ApiResponse.object(res.body);
  }

  /// `GET /client-api/v1/tracking/latest-positions` — latest point of every
  /// owned vehicle whose newest fix falls inside the box.
  Future<List<Map<String, dynamic>>> latestPositionsInBounds({
    required String endpoint,
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        'tracking/latest-positions',
        queryParameters: {
          'minLat': '$minLat',
          'minLon': '$minLon',
          'maxLat': '$maxLat',
          'maxLon': '$maxLon',
        },
      ),
    );
    ApiResponse.ensureOk(res, 'Latest positions');
    return ApiResponse.items(res.body);
  }
}
