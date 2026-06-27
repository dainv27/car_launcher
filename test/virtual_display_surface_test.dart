import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('virtual display hides stale surface without painting over app frames', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'embedding/VirtualDisplayAppView.kt',
    ).readAsStringSync();

    expect(source, isNot(contains('holder.setFormat(PixelFormat.OPAQUE)')));
    expect(source, isNot(contains('surfaceView.setBackgroundColor(Color.BLACK)')));
    expect(source, isNot(contains('clearSurface(holder)')));
    expect(source, contains('surfaceView.visibility = View.INVISIBLE'));
    expect(source, contains('releaseVirtualDisplay()'));
  });

  test('virtual display falls back to accessibility after direct injection fails', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'embedding/VirtualDisplayAppView.kt',
    ).readAsStringSync();
    final accessibility = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'embedding/EmbeddedInputAccessibilityService.kt',
    ).readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(source, contains('directInputAvailable'));
    expect(source, contains('accessibilityGestureRecorder'));
    expect(source, contains('EmbeddedInputAccessibilityService.dispatchGesture'));
    expect(source, isNot(contains('showFallback("Input injection permission missing')));
    expect(accessibility, contains('GestureDescription.Builder()'));
    expect(accessibility, contains('setDisplayId(displayId)'));
    expect(accessibility, contains('dispatchGesture('));
    expect(manifest, contains('EmbeddedInputAccessibilityService'));
    expect(manifest, contains('android.permission.BIND_ACCESSIBILITY_SERVICE'));
  });

  test('virtual display uses bounded per-view readiness retries', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'embedding/VirtualDisplayAppView.kt',
    ).readAsStringSync();

    expect(source, contains('MAX_CREATE_RETRIES'));
    expect(source, contains('BASE_RETRY_DELAY_MS'));
    expect(source, contains('scheduleCreateRetry'));
    expect(source, contains('isReadyToCreate'));
    expect(source, contains('userManager.isUserUnlocked'));
    expect(source, contains('root.isAttachedToWindow'));
    expect(source, contains('holder.surface.isValid'));
    expect(source, contains('removeCallbacks(createRetryRunnable)'));
    expect(source, contains('1L shl'));
  });

  test('Flutter widget creates PlatformViewLink synchronously', () {
    final source = File(
      'lib/features/layout/presentation/widgets/embedded_android_app_view.dart',
    ).readAsStringSync();

    expect(source, contains('PlatformViewLink'));
    expect(source, contains('EmbeddedAndroidAppView'));
    expect(source, contains('virtual_display_app'));
  });
}
