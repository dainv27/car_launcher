# Task

Update the existing Flutter file `navigation_map_widget.dart`.

Do NOT redesign the dashboard architecture.

Do NOT generate a new launcher.

Focus only on modifying the existing `NavigationMapWidget` implementation so it can host a native Android Google Maps TaskView/ActivityView via Flutter PlatformView.

---

# Existing Situation

Current widget structure:

```dart
class NavigationMapWidget extends StatelessWidget
```

Currently `_buildMapBackground()` renders a fake map using:

```dart
CustomPaint(
  painter: _MapGridPainter(),
)
```

This placeholder must be removed.

---

# Required Changes

## 1. Replace Placeholder Map

Replace:

```dart
_buildMapBackground()
```

implementation with a native Android PlatformView.

Example target:

```dart
Widget _buildMapBackground() {
  return const AndroidView(
    viewType: 'google_maps_taskview',
  );
}
```

The PlatformView implementation already exists or will be implemented separately by another task.

DO NOT implement TaskView logic inside this file.

Only consume the PlatformView.

---

## 2. Preserve Existing UI

Keep all existing overlays unchanged:

* Gradient overlay
* Next Turn Card
* Speed Pill
* Speed Limit Pill
* Re-Route Button

Current Stack hierarchy must remain:

```dart
Stack(
  children: [
    GoogleMapsPlatformView,
    GradientOverlay,
    NextTurnCard,
    BottomControls,
  ],
)
```

---

## 3. Platform Awareness

Only render AndroidView on Android.

Example:

```dart
if (Platform.isAndroid)
```

For non-Android platforms show:

```dart
Center(
  child: Text('Google Maps unavailable'),
)
```

---

## 4. Error State

Add support for map host unavailable state.

If PlatformView cannot be created, show:

```dart
Center(
  child: Text('Google Maps unavailable')
)
```

---

## 5. Keep Existing Styling

Do NOT modify:

* CarPlayTheme
* GlassPanel
* Overlay layout
* Border radius
* Positioning
* Typography
* Colors

The visual appearance must remain exactly the same.

Only replace the fake map background with a real Android PlatformView.

---

## 6. Re-Route Button

Update Re-Route button callback.

Instead of TODO comment:

```dart
onPressed: () {}
```

Call:

```dart
GoogleMapsChannel.restartMaps();
```

Assume this helper already exists.

Do not implement MethodChannel logic here.

---

## 7. Output

Return the complete updated version of:

`navigation_map_widget.dart`

with all imports fixed and unused code removed.

Remove:

* _MapGridPainter
* CustomPaint placeholder
* Any dead code related to fake map rendering

Keep everything else unchanged.
