import 'package:car_launcher/features/vehicle/data/map_api_client.dart';
import 'package:car_launcher/features/vehicle/domain/reverse_geocode_result.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_route.dart';

/// Maps the raw `map-client` JSON into domain objects.
class MapRepository {
  MapRepository({required this._apiClient, required this.syncEndpoint});

  final MapApiClient _apiClient;

  /// Vehicle-service base URL override (from the runtime tracking state).
  final String syncEndpoint;

  Future<TrackingRoute> getRoute(
    String vehicleId, {
    DateTime? from,
    DateTime? to,
    double? toleranceMeters,
    int? maxPoints,
  }) async {
    if (vehicleId.isEmpty) return const TrackingRoute();
    final json = await _apiClient.getRoute(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
      from: from,
      to: to,
      toleranceMeters: toleranceMeters,
      maxPoints: maxPoints,
    );
    return TrackingRoute.fromJson(json);
  }

  /// Returns `null` when the reverse-geocoding provider is not configured
  /// (server answered `503`) or produced no name.
  Future<ReverseGeocodeResult?> reverseGeocode(double lat, double lon) async {
    final json = await _apiClient.reverseGeocode(
      endpoint: syncEndpoint,
      lat: lat,
      lon: lon,
    );
    if (json == null) return null;
    final result = ReverseGeocodeResult.fromJson(json);
    return result.hasName ? result : null;
  }

  Future<List<TrackingPoint>> latestPositionsInBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    final raw = await _apiClient.latestPositionsInBounds(
      endpoint: syncEndpoint,
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
    );
    return raw.map(TrackingPoint.fromJson).toList(growable: false);
  }
}
