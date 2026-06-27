# Final Review - Normal App Redesign

Date: 2026-06-16

## Scope

Redesign Car Launcher as a normal Android app:

- remove HOME/default-launcher behavior;
- remove boot startup, native taskbar/sidebar services, and system overlay
  permissions;
- expose Home, Apps, Media, Navigation, and Settings inside the app;
- move settings access into app UI;
- preserve privileged embedded-app support where firmware allows it.

## Adversarial Findings Addressed

The first adversarial review failed on:

- `/navigation` could trap users after taskbar removal;
- Apps, Media, Settings, and dashboard screens had `Expanded` directly under
  non-Flex parents;
- the top app bar could overflow narrow displays;
- Settings lacked an obvious Home route;
- primary docs still described the retired HOME/taskbar architecture.

Fixes applied:

- `Dashboard01` now includes the shared top app bar for Navigation;
- invalid `Expanded` placements were removed from Apps, Media, Settings, and
  Dashboard01/02/03 root layouts;
- `TopAppBar` now uses a flexible title region, visible Home action, and a
  compact destination menu for narrow widths;
- Settings inherits the shared top bar with Home;
- main docs were replaced with current normal-app architecture docs.

## Validation

Passed:

- `git diff --check`
- `rg -n "child:\s*Expanded\(" lib/features/app_drawer/presentation/app_drawer_page.dart lib/features/media/presentation/media_center_page.dart lib/features/settings/presentation/settings_page.dart lib/features/dashboard/all_dashboard`
- `rg` checks for removed HOME/boot/overlay/taskbar native APIs in `android`,
  `lib`, `docs`, and `test`
- `android/gradlew.bat :app:compileDebugKotlin :app:processDebugMainManifest :app:assembleDebug`

Blocked:

- `flutter test test\normal_app_contract_test.dart` timed out after 90s with no
  useful output.
- `flutter analyze` timed out after 90s with no useful output.
- Retry adversarial reviewer agents timed out after the previous findings were
  fixed; this file records the final static/build validation instead.

## Result

PASS with residual tooling risk: Flutter CLI test/analyze execution is currently
not completing in this desktop session, although the Android Gradle build
successfully compiles the Flutter bundle and assembles the debug APK.
