# R05 and R10 integration verification

Accepted predecessor: `f6e111b46c65e17711b93c1cb3f81fb5d8b12450`.
Provider candidate: `cf71de7d043ed965b64487211716b8d0f4babff8`.
Reviewed source tree before release evidence: `6f4017070dbd36d3277042c7312c6a61d8a20dbc`.

## Scope

Combine the reviewed provider configuration, full-budget health, bounded usage, revision/day delivery fences, and terminal accounting/cleanup failure handling with accepted consent withdrawal and administrator re-consent. All runtime blobs match their reviewed parents; schema and English locale retain both parents' additions. No deployed source, live provider, WhatsApp credentials, or customer records changed.

## Actual integration findings

The initial consent/contact-history/concurrency run had 20 examples and three failures. The consent race fixture had no configured AI provider, so R10 correctly prevented its artificial outgoing message from reaching provider HTTP. Creating a configured synthetic provider restores the intended Channel-lock versus authorized-send race without bypassing consent or usage authority. Two old contact-history examples assumed inbox-based access or a successful empty response for unsupported membership; the accepted R06 contract requires assigned-only visibility and a 404 when the contact is inaccessible. The revised test assigns the expected records and preserves unassigned records as exclusions. Production code was not changed to make these tests pass.

Both independent coordinator reviews found no remaining integration issues. The schema retains both provider and consent migrations at version `2026_09_10_000500`; every locale leaf/value from both parents is retained.

## Validation

- Provider models, real adapter boundary, public configuration/usage/delivery, orchestration and recovery: **57 examples, 0 failures**.
- Full public consent and contact history, consent/send races and WhatsApp outbound delivery: **74 examples, 0 failures**.
- Five affected frontend suites: **34 tests, 0 failures**.
- Two coordinator-adjusted Ruby specs: **no lint offenses**.
- Production build and normal-hook identity check: pending final recording.

The 131 Rails examples ran serially in a disposable PostgreSQL 18 database with pgvector and an isolated Redis instance. Ledger pool size was 2 with a 1-second checkout timeout. All provider HTTP was mocked; tests exercised actual jobs, database transactions and recovery. The frontend used the unchanged lockfile and a local offline installation. An earlier cross-worktree dependency symlink failed before test collection; no source or expectations were changed to resolve that environment issue. An accidentally unfiltered frontend invocation was stopped and replaced with an explicit five-file command.

Existing candidate browser evidence is retained in `../2026-09-10-r10/`: actual in-app desktop and 390x844 admin/member, failed full-budget probe, allowance exhaustion, and disable flows. R05's accepted consent browser proof remains valid. No new browser pass is claimed during this integration because the Mac was locked. The separate R07 UI changes are excluded and still require their own acceptance.

The previously documented SandboxRunner booking-conflict baseline failure is not part of these focused integration checks and remains tracked for repair. These results are not a claim that the entire repository test suite passes, V1 is production-ready, or the live answer-quality defects are resolved.

`source-checkpoint.json` records the exact changed app/database/test file bytes. Raw initial failure and final successful results are preserved in `evidence/`; `SHA256SUMS` is generated after final evidence capture.
