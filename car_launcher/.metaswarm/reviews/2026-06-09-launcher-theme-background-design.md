# Design Review: Launcher-Wide Theme and Background

## Decision

Approved with constraints.

## Design

- Persist a launcher visual theme and background preset independently from the
  Android day/night mode.
- Render one background below the router so every launcher route shares it.
- Make primary launcher route surfaces transparent while keeping native Map and
  YouTube surfaces untouched.
- Connect the existing Appearance controls to the persisted provider.
- Keep text contrast suitable for an automotive display.
