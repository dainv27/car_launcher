import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/tracking_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page at /history/:vehicleId showing tracking point history with date
/// range filtering and an export placeholder (UC12 future work).
class TrackingHistoryPage extends ConsumerStatefulWidget {
  const TrackingHistoryPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<TrackingHistoryPage> createState() =>
      _TrackingHistoryPageState();
}

class _TrackingHistoryPageState extends ConsumerState<TrackingHistoryPage> {
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn =
        ref.watch(accountSessionProvider.select((s) => s.valueOrNull != null));

    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: LoginRequiredWidget(featureLabel: 'Tracking history'),
      );
    }

    // Tracking points are scoped to the device attached to this vehicle.
    final vehicleAsync = ref.watch(vehicleProvider(widget.vehicleId));
    final deviceId = vehicleAsync.valueOrNull?.deviceId ?? '';
    final historyAsync = ref.watch(
      trackingHistoryProvider((deviceId, _from, _to)),
    );

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
          _DateRangeBar(
            from: _from,
            to: _to,
            onTap: _showDateRangePicker,
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: CarPlayTheme.neonCyan,
                  strokeWidth: 2,
                ),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: CarPlayTheme.hazardRed.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load tracking history',
                      style: TextStyle(
                        fontSize: 16,
                        color: CarPlayTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(
                        trackingHistoryProvider(
                          (deviceId, _from, _to),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (points) => _HistoryContent(
                points: points,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365));
    final lastDate = now;
    final result = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
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

class _DateRangeBar extends StatelessWidget {
  const _DateRangeBar({
    required this.from,
    required this.to,
    required this.onTap,
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateStyle = TextStyle(
      fontSize: 13,
      color: CarPlayTheme.onSurfaceVariant,
    );
    final label = from != null && to != null
        ? '${_formatDate(from!)} – ${_formatDate(to!)}'
        : 'All time';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: dateStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          OutlinedButton.icon(
            key: const Key('tracking-history-date-range'),
            onPressed: onTap,
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: const Text('Range'),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Coming soon',
            child: OutlinedButton.icon(
              key: const Key('tracking-history-export'),
              onPressed: null,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({required this.points});

  final List<TrackingPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 48,
              color: CarPlayTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No tracking points yet',
              style: TextStyle(
                fontSize: 16,
                color: CarPlayTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: points.length,
      itemBuilder: (context, index) {
        final point = points[index];
        return _TrackingPointTile(point: point);
      },
    );
  }
}

class _TrackingPointTile extends StatelessWidget {
  const _TrackingPointTile({required this.point});

  final TrackingPoint point;

  @override
  Widget build(BuildContext context) {
    final timeStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: CarPlayTheme.onSurface,
    );
    final coordStyle = TextStyle(
      fontSize: 13,
      color: CarPlayTheme.onSurfaceVariant,
    );

    final speedLabel =
        point.speedKph != null ? '${point.speedKph!.toStringAsFixed(1)} km/h' : '--';
    final headingLabel = point.heading != null
        ? '${point.heading!.toStringAsFixed(0)}°'
        : '--';

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
                  _formatTimestamp(point.eventTime),
                  style: timeStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                  style: coordStyle,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(speedLabel, style: timeStyle),
              const SizedBox(height: 4),
              Text(headingLabel, style: coordStyle),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime time) {
    final y = time.year.toString();
    final mo = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final mi = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }
}
