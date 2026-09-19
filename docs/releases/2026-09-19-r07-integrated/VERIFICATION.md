# R07 combined acceptance — 19 September 2026

Status: integrated local acceptance passed; this evidence is included in the normal integration commit. Not deployed or live-verified.

Candidate `222085f21cc93b1746bd53f286601d8cf96150fb` is merged without conflicts on accepted R11 baseline `e859008345fc3e38e55f293ea6e439bac5698e1a`. Both independent reviews cleared the combined contracts. Only PRD, technical design and English locale overlapped; both ticket behaviors remain present. The prior candidate evidence, including four reproduced baseline failures, remains in `docs/releases/2026-09-13-r07-current-review.md`.

## Upgrade and regression evidence

- Fresh owned database `ale_r07_integrated_20260919_spec` loaded the exact e8590083 schema. Schema-load bookkeeping had recorded one new lower-numbered migration despite its table being absent; only the two R07 migration versions were removed from that disposable ledger before normal migration. Both R07 migrations then applied. A synthetic pre-upgrade Account remained present, the resume message boundary is NOT NULL/default 0, and the outbox-effect receipt table exists.
- Combined focused run: 59 examples, 57 passed. Two inherited R11 provider-path tests lacked the R23 active subscription prerequisite and therefore never reached their intended provider failures. Their fixtures now create the required subscription only for those paths; existing assertions remain unchanged.
- The same request file's cleanup previously checked only Rails test mode. It now also uses the existing R11 owned-database guard with exact database equality and explicit truncate opt-in. The initial combined run used only the freshly created owned database; no shared/default database was touched. The corrected file and guard tests ran in `r11_integrated_20260919_test` after its R07 migrations: 19 examples, zero failures. Both independent reviewers cleared the test correction.
- Combined Cockpit and Test Center Vue suites: 33 tests, zero failures.
- Final candidate control/resume regressions: 14 examples, zero failures; normal candidate commit hooks passed. Earlier candidate proofs include real PostgreSQL resume/contact lock ordering and direct coexistence echo versus queued delivery.

Logs: `/tmp/r07-integrated-schema-20260919.log`, `/tmp/r07-integrated-migrate-20260919.log`, `/tmp/r07-integrated-focused-20260919.log`, `/tmp/r07-review-ack-rerun-20260919.log`, `/tmp/r07-integrated-vue-20260919.log`.

## Browser boundary

All browser acceptance uses the Codex in-app browser. Candidate desktop/phone acceptance covered identity, one phone number, assignment, takeover, pause/resume, keyboard operation, public/private persistence, pending-intent cancellation, booking timezone, opt-out preservation and message deduplication. Final combined smoke testing uses the same explicitly guarded synthetic database and localhost-only test server with external requests blocked. No real customer send, provider spend or production deployment is authorized by this evidence.

## Final combined verification

Production build passed in 1m 43s; all 232 manifest entries resolved to existing assets. Final request-spec lint passed. Actual Codex in-app browser confirmed booking summary Jan 8, 2030 at 1:00 PM Africa/Dar_es_Salaam agrees with details 13:00. The phone viewport (390×844) confirmed Pause → AI Paused and Resume → AI Active/unassigned while the durable opt-out warning remained. Both page and body width were 390 pixels. The screenshot is in the coordinator browser transcript. The viewport was reset, test tab closed, and owned Puma process stopped.

Build log: `/tmp/r07-integrated-build-20260919.log`. Browser server log: `/tmp/r07-integrated-browser-20260919.log`. No external requests, live WhatsApp sends, or paid provider calls were used.
