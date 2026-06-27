# Design Review: App Drawer Keyboard Layout

## Decision

Keep the Activity on `adjustNothing` so the native sidebar and embedded apps
remain stable. Apply the reported IME inset only to the App Drawer grid's
scrollable bottom padding.

## Risk Review

- The search bar remains visible and stable while typing.
- Grid tile dimensions do not change when the keyboard opens.
- Bottom-row apps remain reachable by scrolling above the keyboard.
