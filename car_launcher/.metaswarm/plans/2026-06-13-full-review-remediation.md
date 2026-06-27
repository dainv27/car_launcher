# Full Review Remediation Plan

## Decisions

- OAuth clients are public clients. The app ships no client secret and relies on authorization code flow with PKCE.
- Privileged TBox release builds fail closed without platform signing configuration.
- VirtualDisplay embedding is privileged-only. Accessibility input fallback is removed.
- Flutter remains the route authority; native sidebar state follows confirmed Flutter routes.

## Work Units

1. OAuth public-client configuration and callback lifecycle
   - Add failing contracts for no embedded secret and callback forwarding.
   - Remove confidential-client requirements and sensitive callback logging.
   - Forward cold and warm callbacks, buffering until Flutter is ready.

2. Signing, backup, and manifest hardening
   - Add failing manifest/build contracts.
   - Fail release configuration without complete platform credentials.
   - Move shared UID to the manifest root, disable backup, remove spoofable quick boot.

3. WebView and internal broadcast hardening
   - Add failing security policy contracts.
   - Restrict Maps WebView navigation/geolocation to approved HTTPS origins.
   - Disable file/content/mixed-content access and protect pre-Android-13 receivers.

4. Sidebar bridge and MainActivity lifecycle
   - Add failing bridge/lifecycle contracts.
   - Implement native sidebar config methods and remove clock/connectivity from sync signature.
   - Add deterministic receiver/media/channel cleanup.

5. VirtualDisplay readiness and privileged input
   - Replace stale contracts with executable readiness-policy contracts.
   - Add a per-view bounded retry/readiness policy.
   - Remove accessibility fallback and clean up manifest/resources.

6. Media overlay session switching
   - Add failing session lifecycle contracts.
   - Follow active-session changes and safely handle missing overlay permission.

7. Async stale-response protection
   - Add controlled-completion tests where practical.
   - Add request generations and mounted checks to connectivity, location, weather, and app list.

8. Test drift cleanup and final verification
   - Remove contradictory source contracts and align tests with intended behavior.
   - Run Flutter tests/analyze, Android manifest/build checks, adversarial final review.

## External Follow-up

- Rotate/revoke the exposed Keycloak secret and configure `car_launcher` as a public PKCE client.
- Verify the final privileged APK certificate against the TBox platform certificate.
- Run boot, overlay, embedded Maps/YouTube, and OAuth acceptance tests on the physical TBox.

