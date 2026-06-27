# Design Review: Smooth Route Transitions

## Decision

Use a shared `CustomTransitionPage` combining opacity and a small horizontal
translation. Keep the animation short and avoid blur, clipping, or large scale
changes so embedded Android surfaces and Flutter content remain responsive.

## Risks Reviewed

- Embedded surfaces may not animate reliably: transition affects the route
  container only and uses compositing-friendly transforms.
- Repeated sidebar taps may stack routes: existing `context.go` replacement
  navigation is retained.
- Motion accessibility: return the child directly when animations are disabled.
- Splash behavior: use the same subtle transition to avoid an abrupt first frame.
