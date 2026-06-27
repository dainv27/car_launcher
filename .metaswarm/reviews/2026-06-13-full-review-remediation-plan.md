# Plan Review Gate

Status: Pass after revision

The original three-unit plan was split into eight independently reviewable work units.
Each unit requires a failing test or contract first, implementation, validation,
adversarial review, and commit before progressing.

Required final gates:

- No OAuth client secret or static token-encryption secret in source.
- Release never falls back to debug signing.
- Merged manifest has the intended privileged identity and backup policy.
- OAuth callbacks work for cold start and `singleTask` warm return.
- WebView blocks unapproved origins and geolocation requests.
- Sidebar bridge methods exist and native lifecycle resources are cleaned up.
- VirtualDisplay retries only transient readiness failures and cleans up on disposal.
- Media overlay follows session changes.
- Stale asynchronous completions cannot overwrite newer state.
