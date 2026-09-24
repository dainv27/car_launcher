import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

class VehicleTrackingBadge extends ConsumerWidget {
  const VehicleTrackingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(vehicleTrackingProvider);
    final notifier = ref.read(vehicleTrackingProvider.notifier);
    final lastPoint = tracking.lastPoint;

    return DecoratedBox(
      key: const Key('vehicle-tracking-badge'),
      decoration: BoxDecoration(
        color: context.palette.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tracking.enabled
              ? context.palette.accent.withValues(alpha: 0.45)
              : context.palette.foreground.withValues(alpha: 0.14),
        ),
        boxShadow: context.palette.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tracking.enabled ? Icons.gps_fixed : Icons.gps_off_outlined,
              color: tracking.enabled
                  ? context.palette.accent
                  : context.palette.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking.enabled ? 'Tracking vehicle' : 'Tracking paused',
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tracking.formattedDistance} | ${tracking.pendingSyncCount} pending',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (lastPoint?.displayName.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 190,
                    child: Text(
                      lastPoint!.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              key: const Key('vehicle-tracking-toggle'),
              onPressed: tracking.enabled ? notifier.stop : notifier.start,
              style: FilledButton.styleFrom(
                minimumSize: const Size(72, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(tracking.enabled ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleTrackingSettingsCard extends ConsumerWidget {
  const VehicleTrackingSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(vehicleTrackingProvider);
    final notifier = ref.read(vehicleTrackingProvider.notifier);
    final lastPoint = tracking.lastPoint;
    final isLoggedIn = ref.watch(
      accountSessionProvider.select((s) => s.valueOrNull != null),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.route_outlined,
              color: tracking.enabled
                  ? context.palette.accent
                  : context.palette.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Tracking',
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tracking.enabled
                        ? 'Background service records GPS points offline and syncs when internet is validated.'
                        : 'Tracking is paused. Start it to record vehicle movement.',
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              key: const Key('vehicle-tracking-settings-toggle'),
              value: tracking.enabled,
              onChanged: (enabled) =>
                  enabled ? notifier.start() : notifier.stop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _TrackingMetric(
              label: 'Distance',
              value: tracking.formattedDistance,
            ),
            _TrackingMetric(label: 'Points', value: '${tracking.pointCount}'),
            _TrackingMetric(
              label: 'Pending Sync',
              value: '${tracking.pendingSyncCount}',
            ),
            _TrackingMetric(
              label: 'Last Update',
              value: lastPoint == null
                  ? '--'
                  : _formatTime(lastPoint.timestamp),
            ),
          ],
        ),
        if (lastPoint != null) ...[
          const SizedBox(height: 12),
          Text(
            lastPoint.displayName.isEmpty
                ? '${lastPoint.latitude.toStringAsFixed(5)}, ${lastPoint.longitude.toStringAsFixed(5)}'
                : lastPoint.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.palette.textSecondary),
          ),
        ],
        const SizedBox(height: 14),
        _VehicleSummary(vehicle: tracking.vehicle),
        if (tracking.lastVehicleError != null) ...[
          const SizedBox(height: 8),
          Text(
            tracking.lastVehicleError!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.palette.danger, fontSize: 12),
          ),
        ],
        if (tracking.lastSyncError != null) ...[
          const SizedBox(height: 8),
          Text(
            tracking.lastSyncError!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.palette.warning, fontSize: 12),
          ),
        ],
        if (tracking.vehicles.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tracking.vehicles
                .map(
                  (vehicle) => ChoiceChip(
                    label: Text(vehicle.displayName),
                    selected:
                        vehicle.id.isNotEmpty &&
                        vehicle.id == tracking.vehicle.id,
                    onSelected: (_) => notifier.assignVehicle(vehicle),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const Key('vehicle-profile-register'),
              onPressed: isLoggedIn
                  ? () => _showVehicleProfileDialog(
                      context,
                      notifier,
                      tracking.vehicle,
                    )
                  : () => context.push('/login'),
              icon: const Icon(Icons.directions_car_outlined),
              label: const Text('Manage vehicle'),
            ),
            OutlinedButton.icon(
              key: const Key('vehicle-profile-refresh'),
              onPressed: !isLoggedIn
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sign in to load your vehicles.'),
                        ),
                      );
                    }
                  : tracking.isLoadingVehicles
                  ? null
                  : notifier.loadVehicles,
              icon: tracking.isLoadingVehicles
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                tracking.isLoadingVehicles
                    ? 'Loading vehicles'
                    : 'Load vehicles',
              ),
            ),
            OutlinedButton.icon(
              key: const Key('vehicle-tracking-sync-now'),
              onPressed: tracking.canSync && !tracking.isSyncing
                  ? notifier.syncNow
                  : null,
              icon: tracking.isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(tracking.isSyncing ? 'Syncing' : 'Sync now'),
            ),
            OutlinedButton.icon(
              key: const Key('vehicle-tracking-clear'),
              onPressed: tracking.points.isEmpty ? null : notifier.clear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear route'),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _showVehicleProfileDialog(
    BuildContext context,
    VehicleTrackingNotifier notifier,
    Vehicle current,
  ) async {
    final plateNumber = TextEditingController(text: current.plateNumber);
    final name = TextEditingController(text: current.name);
    final make = TextEditingController(text: current.brand);
    final model = TextEditingController(text: current.model);
    final year = TextEditingController(text: current.year);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: context.palette.surface,
        title: Text(
          'Register vehicle',
          style: TextStyle(color: context.palette.textPrimary),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VehicleTextField(
                key: const Key('vehicle-profile-plate-input'),
                controller: plateNumber,
                label: 'Plate number',
              ),
              _VehicleTextField(controller: name, label: 'Vehicle name'),
              _VehicleTextField(controller: make, label: 'Make'),
              _VehicleTextField(controller: model, label: 'Model'),
              _VehicleTextField(
                controller: year,
                label: 'Year',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final trimmedYear = year.text.trim();
      await notifier.saveVehicleProfile(
        Vehicle(
          plateNumber: plateNumber.text.trim(),
          name: name.text.trim(),
          brand: make.text.trim(),
          model: model.text.trim(),
          metadata: trimmedYear.isNotEmpty ? {'year': trimmedYear} : const {},
        ),
      );
    }
    plateNumber.dispose();
    name.dispose();
    make.dispose();
    model.dispose();
    year.dispose();
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final subtitle = vehicle.hasData
        ? [
            if (vehicle.name.isNotEmpty) vehicle.name,
            if (vehicle.brand.isNotEmpty || vehicle.model.isNotEmpty)
              '${vehicle.brand} ${vehicle.model}'.trim(),
            if (vehicle.year.isNotEmpty) vehicle.year,
          ].where((value) => value.isNotEmpty).join(' | ')
        : 'Vehicle is not registered';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registered vehicle',
          style: TextStyle(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          vehicle.displayName,
          style: TextStyle(color: context.palette.textPrimary, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.palette.textSecondary),
        ),
      ],
    );
  }
}

class _VehicleTextField extends StatelessWidget {
  const _VehicleTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: context.palette.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.palette.textSecondary),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: context.palette.foreground.withValues(alpha: 0.24),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingMetric extends StatelessWidget {
  const _TrackingMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.foreground.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
