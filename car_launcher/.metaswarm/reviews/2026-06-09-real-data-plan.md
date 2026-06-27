# Plan Review: Real Data Audit

## Decision

Approved with constraints.

## Review Notes

- Replace only user-visible fabricated values that have a documented Android or
  service source.
- Treat missing TBox, CAN, HVAC, TPMS, and Google Maps guidance APIs as
  unavailable instead of inventing values.
- Keep changes scoped away from unrelated dirty dashboard/theme work.
- Require contract tests, responsive tests, scoped analysis, Android build, and
  emulator verification before commit.
