# Final Review: Unified Splash and Real Connectivity

## Scope reviewed

- Native Android startup window and Flutter splash use the same DaiNV asset,
  dimensions, and gradient.
- Top bar, bottom bar, and native system sidebar consume Android connectivity
  state instead of fixed presentation values.
- Wi-Fi and cellular signal levels remain unavailable (`-1`) when Android
  cannot supply a trustworthy reading.

## Validation

- `flutter test`: 81 tests passed.
- `flutter analyze`: no issues.
- `git diff --check`: clean.
- `android/./gradlew :app:assembleDebug`: successful.
- Bengal device:
  - Wi-Fi RSSI reported by Android: `-18 dBm`.
  - Launcher displayed Wi-Fi `100%` and full signal bars.
  - Cellular data state reported disconnected and was not presented as active.
  - Bluetooth reported enabled but not connected and was displayed dimmed.
  - Battery displayed `100%`.
  - No launcher fatal exception found in logcat.

## Adversarial review

- No mock fallback remains on the three requested status surfaces.
- Permission or hardware limitations do not create a fake positive state.
- Event broadcasts are supplemented by polling so vendor ROMs that omit a
  connectivity broadcast still refresh the native sidebar.
- The Flutter connectivity notifier keeps the last valid snapshot on a
  transient native-channel error.

## Residual risk

- Some ROMs restrict cellular signal strength or Bluetooth profile state unless
  their runtime permissions are granted. The UI intentionally reports those
  values as unavailable rather than estimating them.
