# SDK And Build For TBox

## Toolchain

- Flutter project configuration from this repository.
- Android Gradle Plugin from the Flutter template.
- Java/Kotlin JVM target 17.
- Android package `com.carlauncher.car_launcher`.
- Target Android SDK 35.

Embedded app support depends on ROM capabilities:

- `VirtualDisplay` embedding (the only embed path the Flutter UI currently
  uses) requires Android 10 / API 29 or newer.
- TBox Android 13 remains the primary hardware target.

There is a single Gradle product flavor, `system` (dimension `channel`,
`android/app/build.gradle.kts`), and it is the default/only flavor for every
build type (debug, profile, release) — there is no separate unprivileged
flavor. It applies the `android:sharedUserId="android.uid.system"` manifest
overlay from `android/app/src/system/AndroidManifest.xml` to all builds; see
[docs/PLAN.md](../PLAN.md).

## Debug Build

```bash
flutter pub get
flutter build apk --debug
```

Install:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Every build variant — including this debug build — uses the sole `system`
flavor and therefore declares `android:sharedUserId="android.uid.system"`.
Without the platform signing properties below, it falls back to the debug
key, so it will not actually be granted the system UID/privileged permissions
at install time; treat it as a UI/route/embedded-surface/fullscreen-fallback
validation build, not a plain unprivileged one.

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

The `system` flavor's debug, profile, and release build types are all pinned
to the same platform signing config, so the properties below affect every
build type, not only release. Provide them when building for a privileged
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
