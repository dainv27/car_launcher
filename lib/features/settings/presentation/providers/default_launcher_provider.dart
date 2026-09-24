import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Car Launcher is currently the device's default Home app.
final defaultLauncherStatusProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(launcherServiceProvider);
  while (true) {
    yield await service.isDefaultLauncher();
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});
