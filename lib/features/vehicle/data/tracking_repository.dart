import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/data/vehicle_tracking_store_service.dart';

/// Read side of the tracking history feature (UC9-UC12): queries the server for
/// stored points.
///
/// Writing points is owned by [VehicleTrackingNotifier], which records to the
/// local SQLite queue and pushes to `POST /public-api/v1/devices/me/tracking-points`
/// under device-assertion auth.
class TrackingRepository {
  TrackingRepository({
    required this._syncClient,
    required this._store,
    required this.syncEndpoint,
  });

  final VehicleTrackingSyncClient _syncClient;
  // ignore: unused_field — retained for symmetry / future offline reconciliation.
  final VehicleTrackingStoreService _store;

  /// Endpoint override for the vehicle service base URL.
  final String syncEndpoint;

  /// Fetch the latest tracking point for a vehicle from the server.
  ///
  /// Reads the current vehicle-scoped client API
  /// (`GET /client-api/v1/vehicles/{vehicleId}/tracking-points/latest`).
  Future<TrackingPoint?> getLatestTrackingPoint(String vehicleId) async {
    if (vehicleId.isEmpty) return null;
    return _syncClient.getLatestVehicleTrackingPoint(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
    );
  }

  /// Fetch a paginated list of tracking points for a vehicle from the server.
  ///
  /// Reads the current vehicle-scoped client API
  /// (`GET /client-api/v1/vehicles/{vehicleId}/tracking-points`).
  Future<List<TrackingPoint>> listTrackingPoints(
    String vehicleId, {
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    if (vehicleId.isEmpty) return const [];
    return _syncClient.listVehicleTrackingPoints(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
      from: from,
      to: to,
      page: page,
      size: size,
    );
  }
}
