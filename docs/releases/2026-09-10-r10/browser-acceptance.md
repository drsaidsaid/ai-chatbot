# R10 in-app browser acceptance

Acceptance passed on the disposable `ale_release_r10_browser` database with
Rails on `127.0.0.1:3220`, PostgreSQL on 55510 and Redis on 6410. The launcher
requires Rails test mode and the exact disposable database name, blocks external
network traffic with WebMock, holds jobs in the test adapter and serves the
already verified production Vite assets.

The Codex in-app browser completed these checks:

1. The Admin opened Settings → AI & testing → AI provider at desktop width. The
   page showed Configured separately from Needs attention, 1/25 requests, an
   Africa/Nairobi reset time, unknown provider-reported cost, a blank key field,
   the checked model, 512-token ceiling, revision and timestamp, plus plain
   insufficient-credit recovery guidance.
2. Changing the daily allowance to 26 and saving changed readiness to Not
   checked. Reload preserved 26, kept the key field empty and retained the
   Settings/AI & testing navigation.
3. Check health used the configured 512-token ceiling. The guarded local HTTP
   stub returned 402; the page persisted Needs attention, `2 / 26`, revision 3,
   the check time and credits guidance. The usage ledger recorded the failed
   attempt and kept cost unknown.
4. The second Admin account showed Healthy alongside an exhausted `3 / 3`
   allowance, zero remaining requests, the account-timezone reset and explicit
   text that automation was paused and canceled replies would not be resent.
5. At 390×844 the status, failure guidance, inputs and actions remained readable
   and usable. The responsive Settings selector, related AI tabs and mobile
   navigation remained available.
6. A synthetic Team Member opened the provider URL directly on an isolated
   localhost session. The role guard returned the member to the permitted Inbox;
   provider status and controls were not exposed.
7. After the disposable connection was disabled through the same model boundary
   exercised by the request specs, browser reload showed Not connected,
   Disabled, the durable usage history and “Automation is paused because the AI
   provider is disabled.” Health and disable actions were unavailable.

The accepted Admin and member tabs reported no console errors. The viewport was
reset, tabs were closed and all Rails, PostgreSQL and Redis listeners were
stopped after acceptance. The first two temporary tabs only diagnosed fixture
startup before production asset mode was applied and are not acceptance
evidence.

Sanitized persisted observations are in `browser-acceptance/`. They contain no
key material, password, prompt, reply or customer data.

