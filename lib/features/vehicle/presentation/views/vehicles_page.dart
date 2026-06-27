import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        backgroundColor: CarPlayTheme.deepObsidian,
        title: const Text(
          'Vehicles',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: CarPlayTheme.neonCyan,
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
        backgroundColor: CarPlayTheme.neonCyan,
        child: const Icon(Icons.add, color: CarPlayTheme.deepObsidian),
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
              color: CarPlayTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No vehicles registered',
              style: TextStyle(
                fontSize: 18,
                color: CarPlayTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first vehicle',
              style: TextStyle(
                fontSize: 14,
                color: CarPlayTheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: CarPlayTheme.neonCyan,
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
            color: CarPlayTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(26)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CarPlayTheme.neonCyan.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: CarPlayTheme.neonCyan,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: CarPlayTheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
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
            color: CarPlayTheme.hazardRed.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load vehicles',
            style: TextStyle(
              fontSize: 16,
              color: CarPlayTheme.onSurfaceVariant,
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
              style: const TextStyle(
                color: CarPlayTheme.onSurfaceVariant,
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
