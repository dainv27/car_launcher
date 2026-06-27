import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native connectivity snapshot exposes real signal levels', () {
    final reader = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'ConnectivityStatusReader.kt',
    ).readAsStringSync();

    expect(reader, contains('WifiManager.calculateSignalLevel'));
    expect(reader, contains('signalStrength?.level'));
    expect(reader, contains('getProfileConnectionState'));
    expect(reader, contains('NET_CAPABILITY_VALIDATED'));
    expect(reader, contains('"wifiLevel"'));
    expect(reader, contains('"cellularLevel"'));
    expect(reader, contains('"bluetoothConnected"'));
  });

  test('in-app connection surfaces use the shared real snapshot', () {
    final provider = File(
      'lib/features/dashboard/presentation/providers/dashboard_providers.dart',
    ).readAsStringSync();
    final top = File(
      'lib/features/dashboard/presentation/widgets/top_app_bar.dart',
    ).readAsStringSync();
    final indicator = File(
      'lib/features/dashboard/presentation/widgets/connectivity_indicator.dart',
    ).readAsStringSync();

    expect(provider, contains('NativeBridge.events'));
    expect(indicator, contains("'wifiLevel'"));
    expect(indicator, contains("'cellularLevel'"));
    expect(indicator, contains("'bluetoothConnected'"));
    expect(top, contains('connectivityStatusProvider'));
  });
}
