import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/features/vehicle/data/tracking_repository.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/shared/data/vehicle_tracking_store_service.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the tracking repository — depends on auth and sync endpoint.
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final tracking = ref.watch(vehicleTrackingProvider);
  return TrackingRepository(
    syncClient: VehicleTrackingSyncClient(
      httpClient: httpClient
    ),
    store: VehicleTrackingStoreService(),
    syncEndpoint: tracking.syncEndpoint,
  );
});

/// Latest tracking point for a given vehicle.
final latestTrackingPointProvider =
    FutureProvider.family<TrackingPoint?, String>((ref, vehicleId) async {
  final repo = ref.watch(trackingRepositoryProvider);
  return repo.getLatestTrackingPoint(vehicleId);
});

/// Paginated tracking history for a given vehicle.
///
/// The family argument is a record of (vehicleId, from, to).
final trackingHistoryProvider =
    FutureProvider.family<List<TrackingPoint>, (String, DateTime?, DateTime?)>(
  (ref, args) async {
    final (vehicleId, from, to) = args;
    final repo = ref.watch(trackingRepositoryProvider);
    return repo.listTrackingPoints(vehicleId, from: from, to: to);
  },
);
