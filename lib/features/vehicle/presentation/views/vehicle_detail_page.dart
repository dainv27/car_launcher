import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/vehicle/domain/device.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/device_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/tracking_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page at /vehicles/:id showing vehicle details.
class VehicleDetailPage extends ConsumerWidget {
  const VehicleDetailPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn =
        ref.watch(accountSessionProvider.select((s) => s.valueOrNull != null));

    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: LoginRequiredWidget(featureLabel: 'Vehicle details'),
      );
    }

    final vehicleAsync = ref.watch(vehicleProvider(vehicleId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: CarPlayTheme.deepObsidian,
        title: const Text(
          'Vehicle Details',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: vehicleAsync.when(
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
                'Failed to load vehicle',
                style: TextStyle(
                  fontSize: 16,
                  color: CarPlayTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(vehicleProvider(vehicleId).notifier).refresh(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (vehicle) => _VehicleDetailContent(vehicle: vehicle),
      ),
    );
  }
}

class _VehicleDetailContent extends ConsumerWidget {
  const _VehicleDetailContent({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle info card
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'Plate', value: vehicle.plateNumber),
                const SizedBox(height: 12),
                _InfoRow(label: 'Name', value: vehicle.name),
                const SizedBox(height: 12),
                _InfoRow(label: 'Brand', value: vehicle.brand),
                const SizedBox(height: 12),
                _InfoRow(label: 'Model', value: vehicle.model),
                if (vehicle.year.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Year', value: vehicle.year),
                ],
                if (vehicle.id.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'ID',
                    value: vehicle.id,
                    valueColor: CarPlayTheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),

          // Action buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const Key('vehicle-detail-edit'),
                onPressed: () => _showEditDialog(context, ref, vehicle),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                key: const Key('vehicle-detail-view-history'),
                onPressed: () => context.push('/history/${vehicle.id}'),
                icon: const Icon(Icons.timeline_outlined, size: 18),
                label: const Text('View History'),
              ),
            ],
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),

          _LatestLocationSection(deviceId: vehicle.deviceId),
          const SizedBox(height: CarPlayTheme.widgetGap),

          _AttachedDevicesSection(vehicleId: vehicle.id),
        ],
      ),
    );
  }

  static Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final result = await showDialog<Vehicle?>(
      context: context,
      builder: (_) => VehicleFormDialog(vehicle: vehicle),
    );
    if (result != null && context.mounted) {
      try {
        await ref.read(vehicleProvider(vehicle.id).notifier).updateVehicle(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle updated')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update vehicle: $e')),
          );
        }
      }
    }
  }
}

class _LatestLocationSection extends ConsumerWidget {
  const _LatestLocationSection({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = Row(
      children: [
        Icon(Icons.my_location_outlined, size: 20, color: CarPlayTheme.neonCyan),
        const SizedBox(width: 8),
        Text(
          'Latest Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CarPlayTheme.onSurface,
          ),
        ),
      ],
    );

    if (deviceId.isEmpty) {
      return _GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 8),
            Text(
              'No device assigned to this vehicle',
              style: TextStyle(fontSize: 14, color: CarPlayTheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final latestAsync = ref.watch(latestTrackingPointProvider(deviceId));

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 8),
          latestAsync.when(
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: CarPlayTheme.neonCyan,
                strokeWidth: 2,
              ),
            ),
            error: (error, _) => Text(
              'Failed to load latest location',
              style: TextStyle(fontSize: 14, color: CarPlayTheme.onSurfaceVariant),
            ),
            data: (point) => point == null
                ? Text(
                    'No location data available',
                    style: TextStyle(fontSize: 14, color: CarPlayTheme.onSurfaceVariant),
                  )
                : _LatestLocationDetails(point: point),
          ),
        ],
      ),
    );
  }
}

class _LatestLocationDetails extends StatelessWidget {
  const _LatestLocationDetails({required this.point});

  final TrackingPoint point;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: 'Coords',
          value:
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
        ),
        const SizedBox(height: 8),
        _InfoRow(label: 'Updated', value: _formatTimestamp(point.eventTime)),
        if (point.speedKph != null) ...[
          const SizedBox(height: 8),
          _InfoRow(label: 'Speed', value: '${point.speedKph!.toStringAsFixed(1)} km/h'),
        ],
      ],
    );
  }

  static String _formatTimestamp(DateTime time) {
    final local = time.toLocal();
    final y = local.year.toString();
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }
}

class _AttachedDevicesSection extends ConsumerWidget {
  const _AttachedDevicesSection({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = Row(
      children: [
        Icon(Icons.devices_outlined, size: 20, color: CarPlayTheme.neonCyan),
        const SizedBox(width: 8),
        Text(
          'Attached Devices',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CarPlayTheme.onSurface,
          ),
        ),
      ],
    );

    final devicesAsync = ref.watch(devicesForVehicleProvider(vehicleId));

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 8),
          devicesAsync.when(
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: CarPlayTheme.neonCyan,
                strokeWidth: 2,
              ),
            ),
            error: (error, _) => Text(
              'Failed to load devices',
              style: TextStyle(fontSize: 14, color: CarPlayTheme.onSurfaceVariant),
            ),
            data: (devices) => devices.isEmpty
                ? Text(
                    'No devices',
                    style: TextStyle(fontSize: 14, color: CarPlayTheme.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final device in devices) _DeviceTile(device: device),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.smartphone_outlined, size: 18, color: CarPlayTheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              device.displayName,
              style: TextStyle(fontSize: 14, color: CarPlayTheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CarPlayTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: CarPlayTheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '--' : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? CarPlayTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
