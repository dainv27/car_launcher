# Plan: Accessibility Input Fallback

1. Replace contracts that forbid AccessibilityService with display-aware fallback contracts.
2. Add a private gesture-capable AccessibilityService and manifest configuration.
3. Prefer direct asynchronous injection; switch only after a real injection failure.
4. Record multi-pointer paths and dispatch completed gestures to the Virtual Display.
5. Validate with Flutter tests, Android build, and touch tests on Bengal.
