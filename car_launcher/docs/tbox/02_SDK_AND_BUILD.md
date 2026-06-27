# SDK And Build For TBox

## Toolchain

- Flutter project configuration from this repository.
- Android Gradle Plugin from the Flutter template.
- Java/Kotlin JVM target 17.
- Android package `com.carlauncher.car_launcher`.
- Target Android SDK 35.

Embedded app support depends on ROM capabilities:

- `ActivityView` is attempted only on supported Android builds.
- `VirtualDisplay` embedding requires Android 10 / API 29 or newer.
- TBox Android 13 remains the primary hardware target.

## Debug Build

```bash
flutter pub get
flutter build apk --debug
```

Install:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Debug builds are suitable for validating UI, routes, embedded app surfaces, and
fullscreen fallback behavior. They do not grant privileged system capabilities.

## Android Build Verification

From the repository root:

```powershell
.\gradlew.bat :app:compileDebugKotlin :app:processDebugMainManifest :app:assembleDebug
```

## Flutter Verification

```powershell
flutter test
flutter analyze
```

## Release And Platform Signing

Release builds may require a TBox platform keystore when the ROM expects system
UID signing. Provide Gradle properties only when building for that privileged
deployment path:

```properties
TBOX_PLATFORM_KEYSTORE=/absolute/path/to/platform.jks
TBOX_PLATFORM_KEY_ALIAS=platform
TBOX_PLATFORM_STORE_PASSWORD=...
TBOX_PLATFORM_KEY_PASSWORD=...
```

Then build:

```bash
flutter build apk --release
```

The certificate must match the ROM platform certificate for privileged installs.
