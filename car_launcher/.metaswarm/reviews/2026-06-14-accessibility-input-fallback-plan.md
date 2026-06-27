# Plan Review: Accessibility Input Fallback

The plan preserves the existing privileged path and limits the new service to a
fallback role. The implementation is independently testable through manifest,
display targeting, and primary-path contracts. Device validation must confirm
that direct injection remains active when `INJECT_EVENTS` is granted and that
the fallback does not double-dispatch.
