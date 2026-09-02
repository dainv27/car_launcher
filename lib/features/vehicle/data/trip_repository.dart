import 'package:car_launcher/features/vehicle/data/trip_api_client.dart';
import 'package:car_launcher/features/vehicle/domain/trip.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';

/// Maps the raw `trip-client` JSON into domain [Trip] / [TrackingPoint].
class TripRepository {
  TripRepository({required this._apiClient, required this.syncEndpoint});

  final TripApiClient _apiClient;

  /// Vehicle-service base URL override (from the runtime tracking state).
  final String syncEndpoint;

  Future<List<Trip>> listTrips(
    String vehicleId, {
    DateTime? from,
    DateTime? to,
    TripStatus? status,
    int page = 0,
    int size = 50,
  }) async {
    if (vehicleId.isEmpty) return const [];
    final raw = await _apiClient.listTrips(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
      from: from,
      to: to,
      status: status?.value,
      page: page,
      size: size,
    );
    return raw.map(Trip.fromJson).toList(growable: false);
  }

  Future<Trip> getTrip(String tripId) async {
    final json = await _apiClient.getTrip(
      endpoint: syncEndpoint,
      tripId: tripId,
    );
    return Trip.fromJson(json);
  }

  Future<List<TrackingPoint>> listTripPoints(
    String tripId, {
    int page = 0,
    int size = 200,
  }) async {
    if (tripId.isEmpty) return const [];
    final raw = await _apiClient.listTripPoints(
      endpoint: syncEndpoint,
      tripId: tripId,
      page: page,
      size: size,
    );
    return raw.map(TrackingPoint.fromJson).toList(growable: false);
  }
}
