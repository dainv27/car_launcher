# Responsive Foundation Design Review

## Decision

Use explicit automotive breakpoints instead of globally scaling the entire UI.

## Rationale

- Touch targets and text must remain legible while driving.
- Compact layouts remove secondary controls and reflow content rather than shrinking everything.
- The native sidebar stays 80dp so Flutter content remains aligned with the overlay service.

## Risks Reviewed

- Narrow Settings rail overflow: replaced with a horizontal category selector.
- Media controls overflowing on short displays: compact spacing and hide secondary actions.
- Dashboard cards losing hierarchy: retain the map/right-column composition and simplify card internals.
- Regression at 1920x720: covered by existing reference layout tests.
