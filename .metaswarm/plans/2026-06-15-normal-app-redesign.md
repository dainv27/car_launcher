# Plan: Normal App Redesign

Each work unit follows TDD: add or update contracts, observe failure, implement,
validate, run adversarial review, and commit.

## Work Unit 1: Flutter App Shell

- Add contracts for full-width app content without a persistent taskbar and an
  in-app Settings entry point.
- Remove reserved native-sidebar space and expose Settings from the top bar.
- Remove native sidebar startup, retry, route sync, appearance sync, readiness
  checks, bridge models, and taskbar-only Settings controls.
- Revise only sidebar/default-launcher-specific Flutter contracts while
  retaining unrelated responsive, connectivity, and embedding coverage.

## Work Unit 2: Normal Android Lifecycle

- Add manifest/native contracts for a normal MAIN/LAUNCHER app.
- Remove HOME/default-launcher role APIs, prompt support, preference key,
  BootReceiver, SystemSidebarService, and their native channel operations.
- Remove RECEIVE_BOOT_COMPLETED and sidebar special-use foreground-service
  declarations while preserving embedded-app permissions and behavior.

## Work Unit 3: Remove All System Overlays

- Add contracts requiring no overlay permission, service, or API.
- Replace Google Maps `overlay` fallback with fullscreen app launch fallback.
- Remove MediaOverlayService, its channel operations, manifest declaration,
  SYSTEM_ALERT_WINDOW, and obsolete overlay contracts.

## Work Unit 4: Operational Contracts And Validation

- Update TBox docs/tools and contract tests that positively require removed
  launcher/sidebar/overlay behavior.
- Run full `flutter test`, `flutter analyze`, Android Kotlin compilation and
  debug build, plus embedded-app regression contracts.
- Run final adversarial review and record the final review.
- Update Beads if available; otherwise record that `bd` is unavailable.
- Commit each accepted work unit, then `git pull --rebase`, push, and verify the
  branch is up to date with origin.
