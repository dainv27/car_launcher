import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/map_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/tracking_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/route_map_view.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page at `/history/:vehicleId` — a vehicle's tracking history, shown either
/// as a simplified route on a map or as a list of raw points, filtered by an
/// optional date range.
class TrackingHistoryPage extends ConsumerStatefulWidget {
  const TrackingHistoryPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<TrackingHistoryPage> createState() =>
      _TrackingHistoryPageState();
}

enum _HistoryView { map, list }

class _TrackingHistoryPageState extends ConsumerState<TrackingHistoryPage> {
  DateTime? _from;
  DateTime? _to;
  _HistoryView _view = _HistoryView.map;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(
      accountSessionProvider.select((s) => s.valueOrNull != null),
    );
    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: LoginRequiredWidget(featureLabel: 'Tracking history'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: CarPlayTheme.deepObsidian,
        title: const Text(
          'Tracking History',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _ControlBar(
            from: _from,
            to: _to,
            view: _view,
            onPickRange: _showDateRangePicker,
            onViewChanged: (v) => setState(() => _view = v),
          ),
          Expanded(
            child: _view == _HistoryView.map
                ? _MapBody(vehicleId: widget.vehicleId, from: _from, to: _to)
                : _ListBody(vehicleId: widget.vehicleId, from: _from, to: _to),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (result != null && mounted) {
      setState(() {
        _from = DateTime(
          result.start.year,
          result.start.month,
          result.start.day,
        );
        _to = DateTime(
          result.end.year,
          result.end.month,
          result.end.day,
          23,
          59,
          59,
        );
      });
    }
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.from,
    required this.to,
    required this.view,
    required this.onPickRange,
    required this.onViewChanged,
  });

  final DateTime? from;
  final DateTime? to;
  final _HistoryView view;
  final VoidCallback onPickRange;
  final ValueChanged<_HistoryView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final label = from != null && to != null
        ? '${_fmt(from!)} – ${_fmt(to!)}'
        : 'All time';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: CarPlayTheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SegmentedButton<_HistoryView>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(
                value: _HistoryView.map,
                icon: Icon(Icons.map_outlined, size: 18),
              ),
              ButtonSegment(
                value: _HistoryView.list,
                icon: Icon(Icons.list, size: 18),
              ),
            ],
            selected: {view},
            onSelectionChanged: (s) => onViewChanged(s.first),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('tracking-history-date-range'),
            onPressed: onPickRange,
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: const Text('Range'),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

class _MapBody extends ConsumerWidget {
  const _MapBody({required this.vehicleId, required this.from, required this.to});

  final String vehicleId;
  final DateTime? from;
  final DateTime? to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (vehicleId: vehicleId, from: from, to: to);
    final routeAsync = ref.watch(vehicleRouteProvider(query));

    return routeAsync.when(
      loading: () => const VehicleLoadingView(),
      error: (error, _) => VehicleErrorView(
        message: 'Failed to load route',
        detail: error.toString(),
        onRetry: () => ref.invalidate(vehicleRouteProvider(query)),
      ),
      data: (route) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RouteMapView(
              height: 340,
              distanceKm: route.hasPath ? route.distanceKm : null,
              points: [
                for (final p in route.points)
                  (lat: p.latitude, lon: p.longitude),
              ],
            ),
            const SizedBox(height: 12),
            if (route.hasPath)
              Text(
                '${route.simplifiedCount} of ${route.rawCount} points  ·  '
                '${route.distanceKm.toStringAsFixed(1)} km',
                style: TextStyle(
                  fontSize: 12.5,
                  color: CarPlayTheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ListBody extends ConsumerWidget {
  const _ListBody({required this.vehicleId, required this.from, required this.to});

  final String vehicleId;
  final DateTime? from;
  final DateTime? to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (vehicleId, from, to);
    final historyAsync = ref.watch(trackingHistoryProvider(key));

    return historyAsync.when(
      loading: () => const VehicleLoadingView(),
      error: (error, _) => VehicleErrorView(
        message: 'Failed to load tracking history',
        detail: error.toString(),
        onRetry: () => ref.invalidate(trackingHistoryProvider(key)),
      ),
      data: (points) => points.isEmpty
          ? const VehicleEmptyView(
              icon: Icons.timeline_outlined,
              message: 'No tracking points yet',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: points.length,
              itemBuilder: (context, i) => _TrackingPointTile(point: points[i]),
            ),
    );
  }
}

class _TrackingPointTile extends StatelessWidget {
  const _TrackingPointTile({required this.point});

  final TrackingPoint point;

  @override
  Widget build(BuildContext context) {
    final speedLabel = point.speedKph != null
        ? '${point.speedKph!.toStringAsFixed(1)} km/h'
        : '--';
    final headingLabel =
        point.heading != null ? '${point.heading!.toStringAsFixed(0)}°' : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CarPlayTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatVehicleTimestamp(point.eventTime),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${point.latitude.toStringAsFixed(6)}, '
                  '${point.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                speedLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CarPlayTheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                headingLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: CarPlayTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
