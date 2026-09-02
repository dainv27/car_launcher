import 'package:car_launcher/core/api/api_response.dart';
import 'package:car_launcher/core/api/url_utils.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper over the vehicle-service `trip-client` endpoints.
///
/// All calls are owner-JWT (`client-api/v1`); the injected [http.Client] is
/// the app's `AuthInterceptorClient` and adds the bearer token.
class TripApiClient {
  TripApiClient({required this._httpClient});

  final http.Client _httpClient;

  /// `GET /client-api/v1/vehicles/{vehicleId}/trips`
  Future<List<Map<String, dynamic>>> listTrips({
    required String endpoint,
    required String vehicleId,
    DateTime? from,
    DateTime? to,
    String? status,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        'vehicles/$vehicleId/trips',
        queryParameters: query,
      ),
    );
    ApiResponse.ensureOk(res, 'List trips');
    return ApiResponse.items(res.body);
  }

  /// `GET /client-api/v1/trips/{tripId}`
  Future<Map<String, dynamic>> getTrip({
    required String endpoint,
    required String tripId,
  }) async {
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(endpoint, 'trips/$tripId'),
    );
    ApiResponse.ensureOk(res, 'Get trip');
    return ApiResponse.object(res.body, key: 'trip');
  }

  /// `GET /client-api/v1/trips/{tripId}/tracking-points`
  Future<List<Map<String, dynamic>>> listTripPoints({
    required String endpoint,
    required String tripId,
    int page = 0,
    int size = 200,
  }) async {
    final res = await _httpClient.get(
      UrlUtils.vehicleUri(
        endpoint,
        'trips/$tripId/tracking-points',
        queryParameters: {'page': '$page', 'size': '$size'},
      ),
    );
    ApiResponse.ensureOk(res, 'List trip points');
    return ApiResponse.items(res.body);
  }
}
