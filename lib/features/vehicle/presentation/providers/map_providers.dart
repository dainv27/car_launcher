import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/features/vehicle/data/map_repository.dart';
import 'package:car_launcher/features/vehicle/domain/reverse_geocode_result.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_route.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
