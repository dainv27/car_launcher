import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/features/tracking/data/map_repository.dart';
import 'package:car_launcher/features/tracking/data/tracking_repository.dart';
import 'package:car_launcher/features/tracking/domain/reverse_geocode_result.dart';
import 'package:car_launcher/features/tracking/domain/tracking_point.dart';
import 'package:car_launcher/features/tracking/domain/tracking_route.dart';
import 'package:car_launcher/features/tracking/presentation/tracking_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:car_launcher/features/tracking/presentation/tracking_notifier.dart'
    show
        VehicleTrackingNotifier,
        VehicleTrackingState,
        vehicleTrackingProvider;

/// Provider for the tracking repository — reads the dynamic syncEndpoint
/// from the tracking state and resolves the repository from get_it.
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final tracking = ref.watch(vehicleTrackingProvider);
  return getIt<TrackingRepository>(param1: tracking.syncEndpoint);
});

/// Latest tracking point for a given **vehicle** (vehicle-scoped client API).
final latestTrackingPointProvider =
    FutureProvider.family<TrackingPoint?, String>((ref, vehicleId) async {
  final repo = ref.watch(trackingRepositoryProvider);
  return repo.getLatestTrackingPoint(vehicleId);
});

/// Paginated tracking history for a given **vehicle**.
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

/// Resolves the [MapRepository] for the current runtime sync endpoint.
final mapRepositoryProvider = Provider<MapRepository>((ref) {
  final tracking = ref.watch(vehicleTrackingProvider);
  return getIt<MapRepository>(param1: tracking.syncEndpoint);
});

/// Query for [vehicleRouteProvider].
typedef RouteQuery = ({String vehicleId, DateTime? from, DateTime? to});

/// Simplified (Douglas–Peucker) route polyline for a vehicle over a range.
final vehicleRouteProvider =
    FutureProvider.family<TrackingRoute, RouteQuery>((ref, query) async {
  final repo = ref.watch(mapRepositoryProvider);
  return repo.getRoute(query.vehicleId, from: query.from, to: query.to);
});

/// Query for [reverseGeocodeProvider].
typedef LatLonQuery = ({double lat, double lon});

/// Address for a coordinate — `null` when the provider is unconfigured (503)
/// or produced no name. Never throws for the "unavailable" case.
final reverseGeocodeProvider =
    FutureProvider.family<ReverseGeocodeResult?, LatLonQuery>((ref, q) async {
  final repo = ref.watch(mapRepositoryProvider);
  return repo.reverseGeocode(q.lat, q.lon);
});
