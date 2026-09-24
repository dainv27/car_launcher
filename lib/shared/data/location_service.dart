import 'dart:async';

import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The device's current displayed location (reverse-geocoded place name +
/// coordinates) — used for display only (TopAppBar, weather, dashboard map).
///
/// **Not** used for vehicle tracking — see `features/tracking` for the
/// offline-first vehicle GPS pipeline, which is written to exclusively by
/// the native background service.
class LocationInfo {
  const LocationInfo({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;

  factory LocationInfo.fromMap(Map<Object?, Object?> map) {
    return LocationInfo(
      displayName: map['displayName'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }
}

final currentLocationProvider =
    StateNotifierProvider<LocationNotifier, AsyncValue<LocationInfo?>>((ref) {
      return LocationNotifier();
    });

class LocationNotifier extends StateNotifier<AsyncValue<LocationInfo?>> {
  LocationNotifier() : super(const AsyncValue.loading()) {
    refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  late final Timer _timer;
  bool _permissionRequested = false;
  int _requestGeneration = 0;

  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_requestGeneration;
    try {
      final raw = await NativeBridge.call<Map<Object?, Object?>>(
        'getCurrentLocationInfo',
      );
      if (!mounted || generation != _requestGeneration) return;
      if (raw == null || raw['status'] != 'ok') {
        if (raw?['status'] == 'permission_required' && !_permissionRequested) {
          _permissionRequested = true;
          await NativeBridge.call<bool>('requestLocationPermission');
          if (!mounted || generation != _requestGeneration) return;
          unawaited(
            Future<void>.delayed(const Duration(seconds: 4), () {
              if (mounted && generation == _requestGeneration) refresh();
            }),
          );
        }
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.data(LocationInfo.fromMap(raw));
    } catch (error, stackTrace) {
      if (mounted && generation == _requestGeneration) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    _timer.cancel();
    super.dispose();
  }
}
