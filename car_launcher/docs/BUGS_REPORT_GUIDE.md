# Bug Report Guide

Updated: 2026-06-16

Use this template for bugs in the current normal-app architecture.

## Required Fields

```markdown
## BUG-[id]: [short title]

Severity: Critical | Major | Minor | Trivial
Area: Dashboard | Apps | Media | Navigation | Settings | Native | Tooling
Device:
Android version:
Build type:

### Description

### Steps To Reproduce

1.
2.
3.

### Expected Result

### Actual Result

### Logs / Screenshots
```

## Severity

| Severity | Meaning |
|---|---|
| Critical | App cannot open, core route unusable, crash, data loss |
| Major | Primary feature broken with awkward workaround |
| Minor | Feature works but has layout, copy, or behavior defects |
| Trivial | Small polish issue |

## Current Feature Areas

| Area | Scope |
|---|---|
| Dashboard | Home dashboard, widgets, top bar |
| Apps | Installed app drawer, search, favorites |
| Media | Media center and media session controls |
| Navigation | In-app navigation route and map fallback |
| Settings | All in-app settings categories |
| Native | MethodChannel, PlatformView, embedded app surfaces |
| Tooling | Flutter, Gradle, tests, analysis |

## Out-Of-Scope Bug Categories

Do not file bugs requesting the removed launcher model unless the product scope
changes explicitly. Removed areas include default HOME replacement, boot-start
behavior, persistent taskbar/sidebar services, and system overlay controls.
