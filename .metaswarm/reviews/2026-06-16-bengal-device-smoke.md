# Bengal Device Smoke Test

Date: 2026-06-16

Device:

- product: `bengal_515`
- model: `Bengal for arm64`
- ABI: `arm64-v8a`
- Android: 13 / SDK 33

## Scope

Validate the dashboard after converting Car Launcher back to a normal app while
keeping Google Maps and YouTube embedded side by side through VirtualDisplay
surfaces. Also validate that release builds no longer require platform signing
properties.

## Steps

1. Removed the release build hard-fail for missing `TBOX_PLATFORM_*` signing
   properties.
2. Removed `android:sharedUserId="android.uid.system"` from the release
   manifest so the release APK can install as a normal app.
3. Removed the temporary YouTube WebView PlatformView path.
4. Restored dashboard Maps and YouTube widgets to `EmbeddedAndroidAppView`:
   - Maps: `com.google.android.apps.maps`, `paneId: 1`
   - YouTube: `com.google.android.youtube`, `paneId: 2`
5. Built release APK with `android/gradlew.bat :app:assembleRelease` without
   platform signing properties.
6. Installed release APK with `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
7. Force-stopped Car Launcher, Google Maps, and YouTube.
8. Launched `com.carlauncher.car_launcher/.MainActivity`.
9. Captured foreground activity, screenshot, and logcat.

## Result

PASS for release smoke test:

- Release build succeeds without `TBOX_PLATFORM_KEYSTORE`,
  `TBOX_PLATFORM_KEY_ALIAS`, `TBOX_PLATFORM_STORE_PASSWORD`, or
  `TBOX_PLATFORM_KEY_PASSWORD`.
- Release APK installs successfully as a normal app.
- Car Launcher remains the focused foreground activity after launch.
- Google Maps and YouTube are visible side by side inside the dashboard.
- Activity dump shows both apps were launched by Car Launcher and are visible
  while Car Launcher remains the focused display/task.
- Logcat did not show AndroidRuntime crash, Flutter assertion, or
  `Incorrect use of ParentDataWidget` during the release smoke.

## Screenshot

Captured locally at:

- `%TEMP%/car_launcher_release_virtualdisplay.png`

## Notes

- `flutter test test/normal_app_contract_test.dart` and `flutter analyze`
  timed out after 180 seconds without output in this Windows session. The
  release Gradle build and on-device smoke test both completed successfully.
- VirtualDisplay input/target-display behavior still uses restricted Android
  APIs. Lint suppression is scoped to the reflection helper that resolves
  `InputEvent.setDisplayId`.
