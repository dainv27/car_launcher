# Bug Report Guide

Updated: 2026-09-24

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

Do not file bugs requesting a persistent native taskbar/sidebar service or
`SYSTEM_ALERT_WINDOW`/system overlay UI — those remain out of scope. HOME/
default-launcher registration and boot-start behavior are supported features,
not bugs — see [Plan](PLAN.md).
