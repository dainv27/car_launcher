# Dashboard Space Design Review

## Goal

Increase usable map, media, weather, and YouTube area across all dashboard
variants without removing the native sidebar reservation or status chrome.

## Design Gate

- Use one adaptive spacing policy for every dashboard.
- Preserve touch targets and existing dashboard proportions.
- Reduce dead outer padding and inter-panel gaps.
- Expand Dashboard01 YouTube while preserving the Maps control strip above it.
- Keep layouts overflow-free at TBox and emulator resolutions.

## Risks Reviewed

- Removing the sidebar reservation would put content under the TBox sidebar.
- Zero spacing between embedded surfaces makes touch targets visually ambiguous.
- Fixed large padding wastes a disproportionate amount of compact displays.

## Adversarial Review Resolution

- Preserved a responsive Maps control clearance above Dashboard01 YouTube.
- Replaced hard spacing breakpoints with clamped continuous scaling.
- Geometry tests now measure the actual map, media, weather, and YouTube cards.
