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
  Future<TrackingPoint> createTrackingPoint(String vehicleId, TrackingPoint point) async {
    await _store.appendPending(_toTrackPoint(point, vehicleId));
    unawaited(syncPendingPoints(vehicleId));
    return point;
  }

  /// Fetch the latest tracking point for a vehicle from the server.
  Future<TrackingPoint?> getLatestTrackingPoint(String vehicleId) async {
    return _syncClient.getLatestTrackingPoint(endpoint: syncEndpoint, vehicleId: vehicleId);
  }

  /// Fetch a paginated list of tracking points from the server.
  Future<List<TrackingPoint>> listTrackingPoints(
    String vehicleId, {
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    return _syncClient.listTrackingPoints(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
      from: from,
      to: to,
      page: page,
      size: size,
    );
  }

  /// Sync all pending points for a vehicle with the server.
  ///
  /// Reads pending points from the SQLite store, POSTs them in batches,
  /// and marks them as synced on success.
  Future<void> syncPendingPoints(String vehicleId) async {
    if (vehicleId.isEmpty) return;
    final pending = await _store.readPending();
    if (pending.isEmpty) return;
    const batchSize = 50;
    for (var i = 0; i < pending.length; i += batchSize) {
      final end = (i + batchSize > pending.length) ? pending.length : i + batchSize;
      final batch = pending.sublist(i, end);
      await _syncClient.sync(
        endpoint: syncEndpoint,
        points: batch,
        vehicle: VehicleProfile(vehicleId: vehicleId),
      );
      final syncedIds = batch.map((p) => p.id).toSet();
      await _store.markSynced(syncedIds, DateTime.now().toUtc());
    }
  }

  static VehicleTrackPoint _toTrackPoint(TrackingPoint point, String vehicleId) {
    return VehicleTrackPoint(
      id: point.id,
      latitude: point.latitude,
      longitude: point.longitude,
      displayName: point.metadata['displayName']?.toString() ?? '',
      timestamp: point.eventTime,
    );
  }
}
