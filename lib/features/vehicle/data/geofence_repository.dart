import 'package:car_launcher/features/vehicle/data/geofence_api_client.dart';
import 'package:car_launcher/features/vehicle/domain/geofence.dart';
import 'package:car_launcher/features/vehicle/domain/geofence_event.dart';

/// Maps the raw `geofence-client` JSON into domain [Geofence] /
/// [GeofenceEvent] and back.
class GeofenceRepository {
  GeofenceRepository({
    required this._apiClient,
    required this.syncEndpoint,
  });

  final GeofenceApiClient _apiClient;

  /// Vehicle-service base URL override (from the runtime tracking state).
  final String syncEndpoint;

  Future<List<Geofence>> listGeofences({
    String? vehicleId,
    bool? active,
    int page = 0,
    int size = 50,
  }) async {
    final raw = await _apiClient.listGeofences(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
      active: active,
      page: page,
      size: size,
    );
    return raw.map(Geofence.fromJson).toList(growable: false);
  }

  Future<Geofence> createGeofence(Geofence geofence) async {
    final json = await _apiClient.createGeofence(
      endpoint: syncEndpoint,
      body: geofence.toCreateJson(),
    );
    return Geofence.fromJson(json);
  }

  Future<Geofence> updateGeofence(Geofence geofence) async {
    final json = await _apiClient.updateGeofence(
      endpoint: syncEndpoint,
      geofenceId: geofence.id,
      body: geofence.toUpdateJson(),
    );
    return Geofence.fromJson(json);
  }

  Future<void> deleteGeofence(String geofenceId) {
    return _apiClient.deleteGeofence(
      endpoint: syncEndpoint,
      geofenceId: geofenceId,
    );
  }

  Future<List<GeofenceEvent>> listEvents({
    String? vehicleId,
    String? geofenceId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final raw = await _apiClient.listEvents(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
      geofenceId: geofenceId,
      from: from,
      to: to,
      page: page,
      size: size,
    );
    return raw.map(GeofenceEvent.fromJson).toList(growable: false);
  }
}
