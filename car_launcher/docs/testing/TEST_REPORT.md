# Test Report

Updated: 2026-06-16

## Current Validation Targets

The app is validated as a normal Android app with in-app navigation and no
persistent taskbar or system overlay components.

## Required Checks

```powershell
flutter test
flutter analyze
.\gradlew.bat :app:compileDebugKotlin :app:processDebugMainManifest :app:assembleDebug
```

## Current Known Tooling Issue

On the current workstation, `flutter test` and `flutter analyze` can hang with
no console output because the Flutter/Dart CLI process does not complete. When
that happens, use the Android Gradle build as the compilation check and record
the Flutter CLI timeout explicitly in the review notes.

## Manual QA Focus

- Dashboard top bar on narrow displays.
- Apps route Back and Settings actions.
- Media route Back and Settings actions.
- Navigation route top bar escape path.
- Settings Home escape path.
- Manifest does not expose HOME, boot, or overlay behavior.
