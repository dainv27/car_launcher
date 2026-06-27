# Design review: Bengal embedded app input

## Review result

Approved with the input-capability gate as the primary selection criterion.

## Security

- Do not attempt to bypass Android signature permissions.
- Only the existing allowlisted Maps and YouTube packages receive embedded hosts.
- Accessibility gesture dispatch requires explicit user enablement in system settings.

## Failure modes

- `ActivityView` may be absent or inaccessible on Android 13 aftermarket ROMs.
- Native app embedding without `INJECT_EVENTS` may render but cannot receive touch.
- Accessibility gesture replay occurs when a gesture completes, so visual feedback can lag behind the finger.

## Decision

Prefer privileged native injection, then the explicitly enabled accessibility
input bridge. Keep the native app surface visible while requesting bridge
enablement instead of replacing it with non-native content.
