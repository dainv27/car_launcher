import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/vehicle/domain/trip.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/trip_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/route_map_view.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page at `/trips/:tripId` — one trip's stats and its route on a map.
class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(
      accountSessionProvider.select((s) => s.valueOrNull != null),
    );
    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: LoginRequiredWidget(featureLabel: 'Trip details'),
      );
    }

    final tripAsync = ref.watch(tripDetailProvider(tripId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: CarPlayTheme.deepObsidian,
        title: const Text(
          'Trip',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: tripAsync.when(
        loading: () => const VehicleLoadingView(),
        error: (error, _) => VehicleErrorView(
          message: 'Failed to load trip',
          detail: error.toString(),
          onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
        ),
        data: (trip) => _TripDetailContent(trip: trip),
      ),
    );
  }
}

class _TripDetailContent extends ConsumerWidget {
  const _TripDetailContent({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(tripPointsProvider(trip.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pointsAsync.when(
            loading: () => const RouteMapView(points: []),
            error: (_, _) => const RouteMapView(points: []),
            data: (points) => RouteMapView(
              points: [
                for (final p in points) (lat: p.latitude, lon: p.longitude),
              ],
              distanceKm: trip.distanceKm,
            ),
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  icon: Icons.insights_outlined,
                  label: 'Summary',
                ),
                const SizedBox(height: 12),
                InfoRow(
                  label: 'Status',
                  value: trip.isOpen ? 'Open' : 'Closed',
                  valueColor:
                      trip.isOpen ? CarPlayTheme.toggleOn : null,
                ),
                InfoRow(label: 'Start', value: formatVehicleTimestamp(trip.startTime)),
                InfoRow(label: 'End', value: formatVehicleTimestamp(trip.endTime)),
                InfoRow(
                  label: 'Duration',
                  value: formatVehicleDuration(trip.duration),
                ),
                InfoRow(
                  label: 'Distance',
                  value: '${trip.distanceKm.toStringAsFixed(2)} km',
                ),
                InfoRow(
                  label: 'Avg speed',
                  value: trip.avgSpeedKph == null
                      ? '--'
                      : '${trip.avgSpeedKph!.toStringAsFixed(0)} km/h',
                ),
                InfoRow(
                  label: 'Max speed',
                  value: trip.maxSpeedKph == null
                      ? '--'
                      : '${trip.maxSpeedKph!.toStringAsFixed(0)} km/h',
                ),
                InfoRow(label: 'Points', value: '${trip.pointCount}'),
                if (trip.closeReason != null)
                  InfoRow(label: 'Ended by', value: trip.closeReason!.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
