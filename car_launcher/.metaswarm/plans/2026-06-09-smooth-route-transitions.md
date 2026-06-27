# Smooth Route Transitions

## Goal

Improve perceived smoothness when switching launcher screens without adding
expensive effects that can reduce frame rate on TBox hardware.

## Work Units

1. Add a reusable route transition with short forward/reverse durations.
2. Apply it consistently to all launcher routes.
3. Respect the platform reduced-motion preference.
4. Validate through widget tests, analyzer, and APK build.
