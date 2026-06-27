# Final Review: Accessibility Input Fallback

## Implementation reviewed

- Direct `InputManager.injectInputEvent(..., ASYNC)` remains the preferred path.
- Reflection for input injection and display-ID assignment is cached per pane.
- Per-event synchronous WindowManager transaction calls were removed.
- A gesture-only AccessibilityService targets the Virtual Display ID on Android
  11+ after direct injection actually fails.
- Multi-pointer strokes preserve individual start and end times for Maps pinch.
- Missing `INJECT_EVENTS` no longer blocks Virtual Display rendering.

## Security review

- The service cannot retrieve window content and does not request touch
  exploration.
- Android Accessibility Manager can bind the exported service; binding remains
  protected by `android.permission.BIND_ACCESSIBILITY_SERVICE`.
- Input is forwarded only by the existing allow-listed Virtual Display host.
- Direct and accessibility paths are mutually exclusive for a completed gesture.

## Validation

- Focused input/security contracts: 14 passed.
- `flutter analyze`: no issues.
- `android/./gradlew :app:assembleDebug`: successful.
- `git diff --check`: clean.
- Full `flutter test`: currently fails in 48 pre-existing UI/layout tests,
  primarily invalid `Expanded` placement and overflow errors outside this work.
- Bengal validation could not run because no ADB device was connected.

## Residual behavior

Accessibility gesture dispatch is intentionally a fallback. It batches a
gesture and applies it when the touch sequence completes, so direct
`INJECT_EVENTS` remains preferable for continuous, lowest-latency feedback.
