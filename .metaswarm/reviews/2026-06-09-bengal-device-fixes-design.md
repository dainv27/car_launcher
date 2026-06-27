# Design Review: Bengal Device Fixes

## Finding

The Bengal panel is physically 1920x720 but uses density 238 dpi. Flutter
therefore lays out the app at roughly 1290x484 logical pixels. Existing tests
used DPR 1 and did not exercise this short logical viewport.

## Decision

Make dashboard media content adapt to its actual card height. Preserve the full
layout when enough height is available and reduce nonessential spacing and
header content for short cards.

Restore the embedded-app surface behavior from before `e061ec7e`. That commit
prevented stale frames by painting an opaque black frame into the SurfaceView,
but on Bengal the frame remained above Google Maps and YouTube output. Hide the
SurfaceView before detaching and releasing its VirtualDisplay instead. This
removes stale route content without painting over embedded app frames.

## Risks Reviewed

- Avoid fixed device-name checks; respond to constraints instead.
- Preserve touch target sizes for playback controls.
- Keep standard 1920x720 DPR 1 reference layout unchanged.
- Verify Map -> Settings -> Home -> Map on Bengal to cover both embedded frames
  and the original stale-settings regression.
