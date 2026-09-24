import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_brand_badge.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Standalone page listing all vehicles at /vehicles.
class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn =
        ref.watch(accountSessionProvider.select((s) => s.valueOrNull != null));

    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: LoginRequiredWidget(featureLabel: 'Manage vehicles'),
      );
    }

    final vehiclesAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(
          'Vehicles',
          style: TextStyle(color: context.palette.textPrimary, fontSize: 22),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.palette.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: vehiclesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: context.palette.accent,
            strokeWidth: 2,
          ),
        ),
        error: (error, _) => _VehicleErrorWidget(
          error: error.toString(),
          onRetry: () => ref.read(vehicleListProvider.notifier).refresh(),
        ),
        data: (vehicles) => _VehicleListContent(vehicles: vehicles),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('vehicles-add-fab'),
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: context.palette.accent,
        child: Icon(Icons.add, color: context.palette.onAccent),
      ),
    );
  }

  static Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Vehicle?>(
      context: context,
      builder: (_) => const VehicleFormDialog(),
    );
    if (result != null && context.mounted) {
      try {
        await ref.read(vehicleListProvider.notifier).createVehicle(result);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create vehicle: $e')),
          );
        }
      }
    }
  }
}

class _VehicleListContent extends ConsumerWidget {
  const _VehicleListContent({required this.vehicles});

  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: context.palette.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No vehicles registered',
              style: TextStyle(
                fontSize: 18,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first vehicle',
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: context.palette.accent,
      onRefresh: () => ref.read(vehicleListProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          return _VehicleListTile(vehicle: vehicle);
        },
      ),
    );
  }
}

class _VehicleListTile extends StatelessWidget {
  const _VehicleListTile({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (vehicle.brand.isNotEmpty || vehicle.model.isNotEmpty)
        '${vehicle.brand} ${vehicle.model}'.trim(),
      if (vehicle.year.isNotEmpty) vehicle.year,
    ].where((s) => s.isNotEmpty).join(' | ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () => context.push('/vehicles/${vehicle.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: context.palette.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.palette.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              vehicle.brand.isNotEmpty
                  ? VehicleBrandBadge(brand: vehicle.brand, size: 44)
                  : Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.palette.accent.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.directions_car,
                        color: context.palette.accent,
                        size: 24,
                      ),
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.displayName,
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.palette.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.palette.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleErrorWidget extends StatelessWidget {
  const _VehicleErrorWidget({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: context.palette.danger.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load vehicles',
            style: TextStyle(
              fontSize: 16,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
