/// Navigation-related Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/navigation/data/navigation_service.dart';
import 'package:car_launcher/features/navigation/presentation/navigation_controller.dart';

/// Main navigation state provider
final navigationStateProvider =
    StateNotifierProvider<NavigationController, NavigationStateModel>((ref) {
  final launcher = ref.watch(launcherServiceProvider);
  return NavigationController(launcher);
});

/// Whether navigation is currently active
final isNavigatingProvider = Provider<bool>((ref) {
  return ref.watch(navigationStateProvider).isActive;
});

/// Current navigation provider
final navProviderProvider = Provider<NavigationProvider>((ref) {
  return ref.watch(navigationStateProvider).currentProvider;
});

/// ETA text
final navEtaProvider = Provider<String>((ref) {
  return ref.watch(navigationStateProvider).eta;
});

/// Distance remaining text
final navDistanceProvider = Provider<String>((ref) {
  return ref.watch(navigationStateProvider).distance;
});

/// Destination name/address
final navDestinationProvider = Provider<String>((ref) {
  return ref.watch(navigationStateProvider).destination;
});

/// Next turn instruction
final navNextTurnProvider = Provider<String>((ref) {
  return ref.watch(navigationStateProvider).nextTurn;
});

/// Navigation state enum value
final navStateProvider = Provider<NavState>((ref) {
  return ref.watch(navigationStateProvider).state;
});

/// All available navigation providers
final availableNavProvidersProvider = Provider<List<NavigationProvider>>((ref) {
  return NavigationProvider.values;
});
