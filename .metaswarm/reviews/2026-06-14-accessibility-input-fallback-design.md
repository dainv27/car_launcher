# Design Review: Accessibility Input Fallback

## Decision

Keep `InputManager.injectInputEvent(..., ASYNC)` as the low-latency primary path.
After the first real injection failure, record the current touch gesture and
dispatch subsequent gestures through an opt-in AccessibilityService targeted at
the Virtual Display ID.

## Safety review

- The service is exported so Android's Accessibility Manager can bind it, and
  binding is restricted by the signature permission `BIND_ACCESSIBILITY_SERVICE`.
- It does not retrieve window content or request touch exploration.
- Only the two allow-listed embedded packages can create a hosted pane.
- Accessibility dispatch is unavailable below Android 11 because older APIs
  cannot target a non-default display.
- No gesture is sent through both paths.

## Performance review

- Remove synchronous WindowManager transaction calls from every motion event.
- Use asynchronous direct injection while it succeeds.
- Accessibility fallback batches a complete gesture and dispatches once on
  release, avoiding a Binder call for every move event.
