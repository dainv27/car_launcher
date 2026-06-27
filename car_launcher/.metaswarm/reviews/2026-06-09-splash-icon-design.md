# Splash Icon Design Review

## Scope

Use the supplied transparent launcher icon during both Android native startup
and the Flutter splash animation.

## Design Gate

- Keep the existing dark launch background.
- Replace the native placeholder shape with a centered, bounded bitmap.
- Reuse the same source image in Flutter to avoid a visual jump between phases.
- Preserve the existing splash timing, text, and navigation behavior.

## Risks Reviewed

- A full-resolution `drawable-nodpi` image must be bounded by the layer-list item
  to avoid filling automotive displays.
- The image must be declared in `pubspec.yaml` before Flutter can render it.
- Native and Flutter assets are intentionally duplicated because Android
  resources are not directly available to Flutter's asset bundle.
