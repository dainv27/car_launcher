import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/vehicle/domain/geofence.dart';
import 'package:car_launcher/features/vehicle/domain/geofence_event.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/geofence_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/geofence_form_dialog.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page at `/vehicles/:id/geofences` — geofence CRUD + a transition-events log.
class GeofencesPage extends ConsumerWidget {
  const GeofencesPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(
      accountSessionProvider.select((s) => s.valueOrNull != null),
    );
    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: LoginRequiredWidget(featureLabel: 'Geofences'),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: CarPlayTheme.deepObsidian,
          title: const Text(
            'Geofences',
            style: TextStyle(color: Colors.white, fontSize: 22),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          bottom: const TabBar(
            indicatorColor: CarPlayTheme.neonCyan,
            labelColor: CarPlayTheme.onSurface,
            unselectedLabelColor: CarPlayTheme.onSurfaceVariant,
            tabs: [Tab(text: 'Fences'), Tab(text: 'Events')],
          ),
        ),
        body: TabBarView(
          children: [
            _FencesTab(vehicleId: vehicleId),
            _EventsTab(vehicleId: vehicleId),
          ],
        ),
      ),
    );
  }
}

class _FencesTab extends ConsumerWidget {
  const _FencesTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fencesAsync = ref.watch(geofenceListProvider(vehicleId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'geofence-add',
        backgroundColor: CarPlayTheme.neonCyan,
        onPressed: () => _openForm(context, ref, null),
        child: const Icon(Icons.add, color: CarPlayTheme.deepObsidian),
      ),
      body: fencesAsync.when(
        loading: () => const VehicleLoadingView(),
        error: (error, _) => VehicleErrorView(
          message: 'Failed to load geofences',
          detail: error.toString(),
          onRetry: () => ref.invalidate(geofenceListProvider(vehicleId)),
        ),
        data: (fences) => fences.isEmpty
            ? const VehicleEmptyView(
                icon: Icons.fence_outlined,
                message: 'No geofences yet.\nTap + to add one.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: fences.length,
                itemBuilder: (context, i) => _FenceTile(
                  fence: fences[i],
                  onEdit: () => _openForm(context, ref, fences[i]),
                  onDelete: () => _delete(context, ref, fences[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    Geofence? fence,
  ) async {
    final result = await showDialog<Geofence?>(
      context: context,
      builder: (_) => GeofenceFormDialog(
        geofence: fence,
        vehicleId: vehicleId.isEmpty ? null : vehicleId,
      ),
    );
    if (result == null || !context.mounted) return;
    final notifier = ref.read(geofenceListProvider(vehicleId).notifier);
    try {
      if (fence == null) {
        await notifier.createGeofence(result);
      } else {
        await notifier.updateGeofence(result);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save geofence: $e')),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Geofence fence,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CarPlayTheme.surface,
        title: Text(
          'Delete "${fence.name}"?',
          style: const TextStyle(color: CarPlayTheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(geofenceListProvider(vehicleId).notifier)
          .deleteGeofence(fence.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete geofence: $e')),
        );
      }
    }
  }
}

class _FenceTile extends StatelessWidget {
  const _FenceTile({
    required this.fence,
    required this.onEdit,
    required this.onDelete,
  });

  final Geofence fence;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final detail = fence.isCircle
        ? 'circle · r ${fence.radiusMeters?.toStringAsFixed(0) ?? '?'} m'
        : 'polygon · ${fence.polygon.length} vertices';
    final notify = [
      if (fence.notifyOnEnter) 'enter',
      if (fence.notifyOnExit) 'exit',
    ].join('/');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              fence.isCircle ? Icons.circle_outlined : Icons.pentagon_outlined,
              color: fence.active
                  ? CarPlayTheme.neonCyan
                  : CarPlayTheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fence.name}${fence.active ? '' : ' (inactive)'}',
                    style: const TextStyle(
                      color: CarPlayTheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$detail${notify.isEmpty ? '' : '  ·  notify $notify'}',
                    style: const TextStyle(
                      color: CarPlayTheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: CarPlayTheme.onSurfaceVariant,
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: CarPlayTheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsTab extends ConsumerWidget {
  const _EventsTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(geofenceEventsProvider(vehicleId));

    return eventsAsync.when(
      loading: () => const VehicleLoadingView(),
      error: (error, _) => VehicleErrorView(
        message: 'Failed to load events',
        detail: error.toString(),
        onRetry: () => ref.invalidate(geofenceEventsProvider(vehicleId)),
      ),
      data: (events) => events.isEmpty
          ? const VehicleEmptyView(
              icon: Icons.history,
              message: 'No geofence events yet',
            )
          : RefreshIndicator(
              color: CarPlayTheme.neonCyan,
              onRefresh: () async =>
                  ref.invalidate(geofenceEventsProvider(vehicleId)),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: events.length,
                itemBuilder: (context, i) => _EventTile(event: events[i]),
              ),
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final GeofenceEvent event;

  @override
  Widget build(BuildContext context) {
    final isEnter = event.transition == GeofenceTransition.enter;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              isEnter ? Icons.login : Icons.logout,
              color: isEnter ? CarPlayTheme.toggleOn : CarPlayTheme.cityAmber,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isEnter ? 'Entered' : 'Exited'} '
                    '${event.geofenceName.isEmpty ? 'geofence' : event.geofenceName}',
                    style: const TextStyle(
                      color: CarPlayTheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatVehicleTimestamp(event.eventTime),
                    style: const TextStyle(
                      color: CarPlayTheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
