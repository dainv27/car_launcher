import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('launcher reapplies immersive fullscreen across activity lifecycle', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('applyImmersiveFullscreen()'));
    expect(source, contains('WindowInsets.Type.systemBars()'));
    expect(source, contains('BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE'));
    expect(source, contains('SYSTEM_UI_FLAG_IMMERSIVE_STICKY'));
    expect(
      source,
      contains('override fun onWindowFocusChanged(hasFocus: Boolean)'),
    );
  });
}
