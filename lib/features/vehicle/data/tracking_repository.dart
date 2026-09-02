import 'dart:async';

import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/data/vehicle_tracking_store_service.dart';

/// Repository that wraps [VehicleTrackingSyncClient] + [VehicleTrackingStoreService]
/// for the tracking history feature (UC9-UC12).
///
/// Responsibilities:
/// - [createTrackingPoint] writes to local SQLite and triggers sync
/// - [syncPendingPoints] reads pending from SQLite and POSTs each
/// - [getLatestTrackingPoint] and [listTrackingPoints] query the server
class TrackingRepository {
  TrackingRepository({required this._syncClient, required this._store, required this.syncEndpoint});

  final VehicleTrackingSyncClient _syncClient;
  final VehicleTrackingStoreService _store;

  /// Endpoint override for the vehicle service base URL.
  final String syncEndpoint;

  /// Create a tracking point by inserting into the local pending queue
  /// and triggering an immediate sync.
  Future<TrackingPoint> createTrackingPoint(String deviceId, TrackingPoint point) async {
    await _store.appendPending(_toTrackPoint(point, deviceId));
    unawaited(syncPendingPoints(deviceId));
    return point;
  }

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

  /// Sync all pending points for a device with the server.
  ///
  /// Reads pending points from the SQLite store, POSTs them in batches,
  /// and marks them as synced on success.
  Future<void> syncPendingPoints(String deviceId) async {
    if (deviceId.isEmpty) return;
    final pending = await _store.readPending();
    if (pending.isEmpty) return;
    const batchSize = 50;
    for (var i = 0; i < pending.length; i += batchSize) {
      final end = (i + batchSize > pending.length) ? pending.length : i + batchSize;
      final batch = pending.sublist(i, end);
      await _syncClient.sync(
        endpoint: syncEndpoint,
        points: batch,
        vehicle: VehicleProfile(deviceId: deviceId),
      );
      final syncedIds = batch.map((p) => p.id).toSet();
      await _store.markSynced(syncedIds, DateTime.now().toUtc());
    }
  }

  static VehicleTrackPoint _toTrackPoint(TrackingPoint point, String deviceId) {
    return VehicleTrackPoint(
      id: point.id,
      latitude: point.latitude,
      longitude: point.longitude,
      displayName: point.metadata['displayName']?.toString() ?? '',
      timestamp: point.eventTime,
    );
  }
}
