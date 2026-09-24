import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/vehicle/domain/trip.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/trip_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page at `/vehicles/:id/trips` — the vehicle's segmented trips.
class VehicleTripsPage extends ConsumerStatefulWidget {
  const VehicleTripsPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleTripsPage> createState() => _VehicleTripsPageState();
}

class _VehicleTripsPageState extends ConsumerState<VehicleTripsPage> {
  TripStatus? _status;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(
      accountSessionProvider.select((s) => s.valueOrNull != null),
    );
    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: LoginRequiredWidget(featureLabel: 'Trips'),
      );
    }

    final query = (
      vehicleId: widget.vehicleId,
      from: null,
      to: null,
      status: _status,
    );
    final tripsAsync = ref.watch(tripListProvider(query));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: CarPlayTheme.deepObsidian,
        title: const Text(
          'Trips',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _StatusFilterBar(
            selected: _status,
            onChanged: (value) => setState(() => _status = value),
          ),
          Expanded(
            child: tripsAsync.when(
              loading: () => const VehicleLoadingView(),
              error: (error, _) => VehicleErrorView(
                message: 'Failed to load trips',
                detail: error.toString(),
                onRetry: () => ref.invalidate(tripListProvider(query)),
              ),
              data: (trips) => trips.isEmpty
                  ? const VehicleEmptyView(
                      icon: Icons.route_outlined,
                      message: 'No trips in this view',
                    )
                  : RefreshIndicator(
                      color: CarPlayTheme.neonCyan,
                      onRefresh: () async =>
                          ref.invalidate(tripListProvider(query)),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: trips.length,
                        itemBuilder: (context, i) => _TripTile(trip: trips[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onChanged});

  final TripStatus? selected;
  final ValueChanged<TripStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, TripStatus? value) {
      final active = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: active,
          onSelected: (_) => onChanged(value),
          selectedColor: CarPlayTheme.neonCyan.withValues(alpha: 0.25),
          backgroundColor: CarPlayTheme.surfaceVariant,
          labelStyle: TextStyle(
            color: active ? CarPlayTheme.onSurface : CarPlayTheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip('All', null),
            chip('Open', TripStatus.open),
            chip('Closed', TripStatus.closed),
          ],
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final when = formatVehicleTimestamp(trip.startTime);
    final subtitle = [
      '${trip.distanceKm.toStringAsFixed(1)} km',
      formatVehicleDuration(trip.duration),
      if (trip.avgSpeedKph != null)
        'avg ${trip.avgSpeedKph!.toStringAsFixed(0)} km/h',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => context.push('/trips/${trip.id}'),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (trip.isOpen
                          ? CarPlayTheme.toggleOn
                          : CarPlayTheme.neonCyan)
                      .withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  trip.isOpen ? Icons.play_arrow_rounded : Icons.route,
                  color: trip.isOpen
                      ? CarPlayTheme.toggleOn
                      : CarPlayTheme.neonCyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      when,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: CarPlayTheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (trip.isOpen)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    'OPEN',
                    style: TextStyle(
                      color: CarPlayTheme.toggleOn,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right,
                color: CarPlayTheme.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
