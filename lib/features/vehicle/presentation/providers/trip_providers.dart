import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/features/vehicle/data/trip_repository.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/features/vehicle/domain/trip.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the [TripRepository] for the current runtime sync endpoint.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final tracking = ref.watch(vehicleTrackingProvider);
  return getIt<TripRepository>(param1: tracking.syncEndpoint);
});

/// Filter for [tripListProvider].
typedef TripQuery = ({
  String vehicleId,
  DateTime? from,
  DateTime? to,
  TripStatus? status,
});

/// Trips for a vehicle, newest first (server order).
final tripListProvider =
    FutureProvider.family<List<Trip>, TripQuery>((ref, query) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.listTrips(
    query.vehicleId,
    from: query.from,
    to: query.to,
    status: query.status,
  );
});

/// A single trip by id.
final tripDetailProvider =
    FutureProvider.family<Trip, String>((ref, tripId) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.getTrip(tripId);
});

/// The tracking points that make up a trip, oldest first.
final tripPointsProvider =
    FutureProvider.family<List<TrackingPoint>, String>((ref, tripId) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.listTripPoints(tripId);
});
