import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accessibility input fallback is display-aware and gesture-only', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'embedding/EmbeddedInputAccessibilityService.kt',
    ).readAsStringSync();
    final config = File(
      'android/app/src/main/res/xml/embedded_input_accessibility_service.xml',
    ).readAsStringSync();

    expect(source, contains('Build.VERSION_CODES.R'));
    expect(source, contains('setDisplayId(displayId)'));
    expect(source, isNot(contains('FLAG_REQUEST_TOUCH_EXPLORATION_MODE')));
    expect(source, contains('data class RecordedStroke'));
    expect(source, contains('stroke.startTimeMs'));
    expect(config, contains('android:canPerformGestures="true"'));
    expect(config, contains('android:canRetrieveWindowContent="false"'));
  });

  test('direct input remains the preferred low-latency path', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'embedding/VirtualDisplayAppView.kt',
    ).readAsStringSync();

    expect(source, contains('if (directInputAvailable)'));
    expect(source, contains('directInputAvailable = injectInputEvent'));
    expect(source, contains('INJECT_INPUT_EVENT_MODE_ASYNC'));
    expect(source, contains('private val injectInputEventMethod: Method? by lazy'));
    expect(source, contains('private val setDisplayIdMethod: Method? by lazy'));
    expect(source, contains('private val displayIdField: Field? by lazy'));
    expect(source, isNot(contains('syncInputTransactions()')));
  });

  test('missing INJECT_EVENTS no longer blocks VirtualDisplay rendering', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'embedding/VirtualDisplayEmbeddingCapability.kt',
    ).readAsStringSync();

    expect(source, contains('listOf(ADD_TRUSTED_DISPLAY)'));
    expect(source, contains('EmbeddedInputAccessibilityService.isReady()'));
    expect(source, contains('enable AccessibilityService for input fallback'));
  });
}
