# Design review: keyboard and system sidebar stability

## Result

Approved. The launcher is a full-screen automotive shell, so the IME may cover
content but must not resize the dashboard or move the persistent sidebar.

## Risks

- `adjustNothing` means ordinary launcher text fields must manage IME overlap.
- Ignoring overlay insets is appropriate only because the sidebar intentionally
  replaces the left system rail.

## Decision

Preserve the full launcher geometry and update only sidebar icon colors and
active indicators during route changes.
