import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native bridge exposes Google-backed reverse geocoded location', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('"getCurrentLocationInfo"'));
    expect(source, contains('Geocoder('));
    expect(source, contains('getFromLocation'));
  });
}
