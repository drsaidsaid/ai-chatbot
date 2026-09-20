# R14 integrated acceptance

Integration base: `f52fdacdc7d40435b8e3fffbdeabec6376c9b40e`. Reviewed candidate: `a30a44f20126fcd6476617972672fc59fb970b56`. Parent R19 pilot safeguards preserved.

## Checks

- Combined setup, alert settings, review, knowledge, handoff and booking services: 110 examples, zero failures.
- Actual PostgreSQL authority/concurrency: 16 examples, zero failures. Includes duplicate Review replay, rollback, outer transaction visibility, stale Knowledge lock-set restart and retry/dispatch locking.
- Review/Knowledge Vue: 14 tests passed.
- Browser-fix Inbox API: 6 examples, zero failures; Settings navigation: 1 test passed.
- Final production Vite build after browser fixes: exit 0, 1m25s. Existing chunk-size warnings remain.
- Standards review: no hard documented violations. Specification review cleared transaction, locking and recipient authority fixes; coordinator reviewed final navigation/queue delta.

The initial combined test invocation omitted synthetic encryption keys, causing 22 fixture setup failures. Supplying test-only keys passed without product changes. Earlier broad Operational Dashboard assertions outside this ticket remain documented in the ticket evidence, not claimed passing here.

## Actual in-app browser

Canonical Rails/Vue code and final assets ran at `http://127.0.0.1:3234`, isolated database `ale_r14_acceptance_20260920_spec`, iab1/tab16. WebMock blocked external networking; jobs and mail used test adapters. No actual WhatsApp, AI or calendar calls were made.

- Team alert recipient change saved and survived reload; restored original route.
- Default owner saved correctly; corrected visible navigation reaches it from Team & alerts. Manage team members opens the team-member list.
- Urgent Review assignment changed to R14 Default Owner. Its canonical Conversation showed matching owner and Human Active. Read-only database check confirmed matching owner IDs and one `human_review_assignment` audit.
- Draft Knowledge canceled delivery showed Retry; invoking it changed visible state to queued and removed Retry. Database still had exactly one alert Message.
- Booking link opened the correct canonical booked-lead Conversation.
- Actual Inbox Hot leads initially incorrectly included a booked lead; corrected query and count now show only the one open actionable handoff. API regression also excludes a booked open handoff and highly-qualified lead without handoff.
- Default-owner settings checked visually at actual 390x844 browser viewport; controls and related navigation remained usable. Viewport reset afterward.

Fixtures and server commands are preserved in ignored `local/r14-acceptance/`. Raw local logs: `/tmp/r14-r19-canonical-focused-encrypted.log`, `/tmp/r14-canonical-concurrency.log`, `/tmp/r14-canonical-vue.log`, `/tmp/r14-inbox-fixed-canonical.log`, `/tmp/r14-navigation-fixed-canonical.log`, `/tmp/r14-browser-fixed-vite.log`. Source hashes accompany this record.

This accepts local integrated R14 behavior. Deployment and real-model English/Swahili response quality remain separate pilot gates; R17/R18 full contracts remain open.
