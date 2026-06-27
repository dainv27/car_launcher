/// Navigation controller — manages navigation state and app launching
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/navigation/data/navigation_service.dart';

/// Navigation controller — manages state and communicates with native
class NavigationController extends StateNotifier<NavigationStateModel> {
  NavigationController(this._launcher) : super(NavigationStateModel.idle) {
    _init();
  }

  final LauncherService _launcher;
  static const _navEventChannel = EventChannel('com.carlauncher/nav_events');
  StreamSubscription<dynamic>? _subscription;

  void _init() {
    _subscription = _navEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          try {
            final model = NavigationStateModel.fromJson(
              Map<String, dynamic>.from(event),
            );
            state = model;
          } catch (_) {
            // Ignore malformed events
          }
        }
      },
      onError: (_) {
        // Keep last known state
      },
    );
  }

  /// Launch the current navigation provider app
  Future<bool> launchNavigation() async {
    return _launcher.launchApp(state.currentProvider.packageName);
  }

  /// Launch a specific navigation provider
  Future<bool> launchProvider(NavigationProvider provider) async {
    return _launcher.launchApp(provider.packageName);
  }

  /// Switch the active navigation provider
  Future<void> switchProvider(NavigationProvider provider) async {
    const channel = MethodChannel('com.carlauncher/navigation');
    try {
      final launched = await channel.invokeMethod<bool>('switchProvider', {
        'packageName': provider.packageName,
      });
      if (launched == true) {
        state = state.copyWith(currentProvider: provider);
      }
    } on PlatformException {
      // Keep the last confirmed provider.
    }
  }

  /// Stop navigation
  Future<void> stopNavigation() async {
    const channel = MethodChannel('com.carlauncher/navigation');
    try {
      await channel.invokeMethod('stopNavigation');
    } on PlatformException {
      // Ignore
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for the navigation controller
final navigationControllerProvider =
    StateNotifierProvider<NavigationController, NavigationStateModel>((ref) {
      final launcher = ref.watch(launcherServiceProvider);
      return NavigationController(launcher);
    });

/// Provider for navigation active state
final isNavigatingProvider = Provider<bool>((ref) {
  return ref.watch(navigationControllerProvider).isActive;
});

/// Provider for current navigation provider
final navProviderProvider = Provider<NavigationProvider>((ref) {
  return ref.watch(navigationControllerProvider).currentProvider;
});

/// Provider for ETA text
final navEtaProvider = Provider<String>((ref) {
  return ref.watch(navigationControllerProvider).eta;
});

/// Provider for distance text
final navDistanceProvider = Provider<String>((ref) {
  return ref.watch(navigationControllerProvider).distance;
});

/// Provider for destination text
final navDestinationProvider = Provider<String>((ref) {
  return ref.watch(navigationControllerProvider).destination;
});

/// Provider for next turn instruction
final navNextTurnProvider = Provider<String>((ref) {
  return ref.watch(navigationControllerProvider).nextTurn;
});
