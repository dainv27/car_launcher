import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/features/device/domain/device.dart';
import 'package:car_launcher/features/device/data/device_service.dart';
import 'package:car_launcher/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Devices attached to a given vehicle (by vehicle ID).
final devicesForVehicleProvider =
    FutureProvider.family<List<Device>, String>((ref, vehicleId) async {
  if (vehicleId.isEmpty) return const [];
  final tracking = ref.watch(vehicleTrackingProvider);
  final service = getIt<DeviceService>();
  final raw = await service.listDevices(
    endpoint: tracking.syncEndpoint,
    vehicleId: vehicleId,
  );
  return raw.map(Device.fromJson).toList(growable: false);
});
