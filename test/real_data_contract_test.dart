import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard status bar uses native connectivity without battery data', () {
    final source = File(
      'lib/features/dashboard/presentation/widgets/bottom_status_bar.dart',
    ).readAsStringSync();

    expect(source, contains('connectivityStatusProvider'));
    expect(source, contains('showLabels: false'));
    expect(source, contains("Key('bottom-bar-mobile-network')"));
    expect(source, contains('Tooltip('));
    expect(source, contains('Semantics('));
    expect(source, contains("'cellular'"));
    expect(source, contains("'cellularLevel'"));
    expect(source, contains("'cellularOperator'"));
    expect(source, contains("'cellularNetworkType'"));
    expect(source, isNot(contains("'batteryLevel'")));
    expect(source, isNot(contains('Icons.battery_')));
    expect(source, isNot(contains('Battery unavailable')));
    expect(source, isNot(contains('mockThermostat')));
    expect(source, isNot(contains('mockTpms')));
    expect(source, isNot(contains("'System Online'")));
  });

  test('dashboard actions open real Android notification and voice surfaces', () {
    final topBar = File(
      'lib/features/dashboard/presentation/widgets/top_app_bar.dart',
    ).readAsStringSync();
    final native = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
    ).readAsStringSync();

    expect(topBar, contains("'openNotificationAccessSettings'"));
    expect(topBar, contains("'launchVoiceAssistant'"));
    expect(native, contains('"hasNotificationListenerAccess"'));
    expect(native, contains('"openNotificationAccessSettings"'));
    expect(native, contains('"launchVoiceAssistant"'));
  });

  test('startup checks and requests required permissions when app opens', () {
    final app = File('lib/main.dart').readAsStringSync();
    final native = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
    ).readAsStringSync();

    expect(app, contains('_StartupPermissionGate'));
    expect(app, contains("'ensureStartupPermissions'"));
    expect(native, contains('"ensureStartupPermissions"'));
    expect(native, contains('requiredRuntimePermissions()'));
    expect(native, contains('requestPermissions('));
    expect(native, contains('STARTUP_PERMISSION_REQUEST'));
    expect(native, contains('hasInputAccessibilityAccess()'));
    expect(native, contains('openAccessibilitySettings()'));
    expect(native, contains('Settings.ACTION_ACCESSIBILITY_SETTINGS'));
    expect(native, contains('openNotificationAccessSettings()'));
  });

  test('media controls send all playback commands to active MediaSession', () {
    final dart = File(
      'lib/features/media/data/media_controller.dart',
    ).readAsStringSync();
    final native = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
    ).readAsStringSync();

    for (final action in ['play', 'pause', 'next', 'previous', 'seekTo']) {
      expect(dart, contains("'$action'"), reason: action);
      expect(native, contains('"$action"'), reason: action);
    }
    expect(dart, isNot(contains('state = state.copyWith(state:')));
    expect(native, contains('addOnActiveSessionsChangedListener'));
    expect(native, contains('activeMediaController?.transportControls'));
  });

  test('navigation never fabricates provider state or stop success', () {
    final source = File(
      'lib/features/navigation/presentation/navigation_controller.dart',
    ).readAsStringSync();
    final native = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
    ).readAsStringSync();

    expect(source, isNot(contains('setMockState')));
    expect(source, contains('if (launched == true)'));
    expect(native, isNot(contains('getNavStateMap()')));
    expect(
      native,
      isNot(contains('com.google.android.gms.navigation.STOP_NAVIGATION')),
    );
    expect(native, contains('private fun stopNavigation(): Boolean = false'));
    expect(
      File(
        'lib/features/navigation/presentation/widgets/navigation_widget.dart',
      ).readAsStringSync(),
      isNot(contains('controller.stopNavigation()')),
    );
  });

  test('network online state requires Android validated internet', () {
    final footer = File(
      'lib/features/dashboard/presentation/widgets/bottom_status_bar.dart',
    ).readAsStringSync();
    final native = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'ConnectivityStatusReader.kt',
    ).readAsStringSync();

    expect(footer, contains("connectivity['validated'] == true"));
    expect(native, contains('NET_CAPABILITY_VALIDATED'));
    expect(native, contains('"cellularOperator"'));
    expect(native, contains('"cellularNetworkType"'));
    expect(native, contains('networkTypeName'));
  });

  test('weather never falls back to a fabricated city', () {
    final source = File(
      'lib/features/dashboard/data/weather_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("??\n        'Hanoi'")));
    expect(source, contains('if (city == null || city.isEmpty)'));
  });
}
