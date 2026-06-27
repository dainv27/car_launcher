import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/features/vehicle/data/tracking_repository.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the tracking repository — reads the dynamic syncEndpoint
/// from the tracking state and resolves the repository from get_it.
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final tracking = ref.watch(vehicleTrackingProvider);
  return getIt<TrackingRepository>(param1: tracking.syncEndpoint);
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
