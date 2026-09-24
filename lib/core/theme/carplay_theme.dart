/// Layout tokens for the in-car UI.
///
/// Colours live in `LauncherPalette` (read with `context.palette`) so they
/// follow Day/Night mode and the accent preset.
abstract final class CarPlayTheme {
  static const dockWidth = 88.0;
  static const appIconSize = 80.0;
  static const appIconRadius = 16.0;
  static const carMinTouchTarget = 88.0;

  static const gutter = 24.0;
  static const margin = 32.0;
  static const widgetGap = 16.0;
  static const touchTargetMin = 64.0;
}
