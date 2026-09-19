# R13 integrated acceptance evidence

Candidate: `8fdd225ed9aea2cf3bf958513acf5e3fe2bd8171`. Baseline: `b4be1a684dec9006b46afae967a2abfa75f933db`.

The coordinator merged with `--no-ff --no-commit`. The resulting staged tree was exactly `4d2d0dbd6157a00a48d5d5cd2d8da439e2c96cd5`, identical to the tested candidate. No conflict or combined runtime change occurred; repeating the same tests/build solely for the new checkout is unnecessary. Source hashes are recorded alongside this file.

## Review and automated checks

Independent specification and standards reviews cleared backend source tree `83cc6cc37c879d9357dcfe5bd4f46d0a09ac03d6`. The coordinator reviewed the subsequent two-file UI correction: range navigation uses the server boundary and canceled bookings hide mutation actions on desktop and mobile.

Worker evidence: final backend scope 67 examples, no failures (`/tmp/r13-final-review-corrections-backend.log`); mutation/client 23 examples, no failures (`/tmp/r13-reconcile-review-fix.log`); prior affected frontend 34 tests passed, followed by the final BookingsPanel 8/8 (`/tmp/r13-bookings-panel-final-vitest.log`). Scoped ESLint and 43 Ruby files passed. Final production build transformed 5,091 modules and completed in 32m21s (`/tmp/r13-final-ui-vite-build.log`). No runtime source changed afterward.

A fresh owned database `ai_chatbot_r13_upgrade_20260919_83cc6cc` loaded the exact accepted baseline schema, then ran migration `20260919000300`. The synthetic Account and prior commercial/review tables survived; generation and booking columns were verified. Logs: `/tmp/r13-upgrade-{schema-load,before,migrate,after}.log`.

## Coordinator in-app browser evidence

Actual Codex in-app browser, desktop and 390×844 viewport, localhost port 3103; guarded database `ai_chatbot_r13_browser_83cc6cc`. Fake Google adapter, WebMock denying nonlocal requests, test jobs/mail, no real OAuth or external sends.

- Unknown reschedule reconciled from 10:00 to the provider-confirmed 12:00; unknown cancellation reconciled to canceled on the phone layout. Each queued one canonical notice.
- Final rebuilt UI advanced the default Sep14–21 range to Sep21–28, retaining all fixture bookings. Canceled detail had no reschedule/cancel action on desktop or phone. Phone viewport/page/body widths were all 390.
- Eligible conversation 4 displayed only the agreed Sep24 11:00 time. Confirm created durable booking 5 at 08:00 UTC / 11:00 Africa/Dar_es_Salaam, provider-confirmed, with one confirmation message. No voluntary-email checkbox was selected.
- Agenda and Calendar showed the same created/rescheduled/canceled records.
- Buffer-before 15 minutes and unavailable date Sep28 saved and persisted after navigation/reload.
- Disconnecting the synthetic calendar removed credentials and availability showed explicit reconnect guidance with no offered slots.

Coordinator SQL independently verified the durable booking states and one notice each for conversations 2, 3, and 4. A worker proof file contained an incorrect booking-id JSON-path query returning zero; it is not used as evidence of message count. The coordinator used conversation identity and exact message purpose instead.

The browser tab was closed, viewport reset, and Puma terminated; fixture database remains for audit. Real Google OAuth, live WhatsApp delivery and deployment are not claimed. Candidate normal pre-commit hooks passed; integration commit checks must pass normally as well.
