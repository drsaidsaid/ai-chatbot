# R23 monthly plans and logical AI reply metering

Date: 2026-09-12  
Branch: `codex/r23-monthly-plans`  
Approved base: `58aaf41115a5d52e7566187b99defde6ba80da2a`
Final source: `190945e22e96341c83a1c7f2cc269942924abbca`

## Demonstrated path

- Platform finance operators can publish immutable, versioned monthly plans and confirm an approved manual payment exactly once.
- Business Account administrators can request a new subscription, renewal, fixed approved top-up, or same-currency upgrade, but cannot confirm payment.
- A confirmation revalidates the plan, subscription status, and entitlement snapshot under lock so stale or reordered requests cannot change an entitlement.
- Customer-facing AI work reserves one unit before calling the model. HTTP acceptance remains reserved; a logical reply settles once only after every registered WhatsApp delivery part has a canonical `sent`, `delivered`, or `read` provider receipt.
- Failed sends release the unit; unknown sends remain reserved. A terminal mixed sent/failed multi-part reply becomes a visible `partially_delivered` hold: it is not billed, released, or automatically resent. An authorised retry reuses only a fully released logical-reply record.
- Calendar-month rollover uses the Business Account reporting timezone and renewal anchor. Unpaid renewal or exhausted allowance pauses AI while preserving inbound capture and the human inbox.
- Exhaustion and renewal alerts are durable, visible in Billing, and queued to configured Business Account owner WhatsApp recipients without consuming an AI reply. Alert retries reuse the same message.
- Billing displays subscription usage separately from Meta messaging and advertising charges. Platform reporting scopes provider costs to the exact subscription timestamps, separates revenue by currency, and marks provider-cost and margin completeness honestly.

## Verification evidence

The tracked `*.log` files in this directory are curated command/result excerpts, not byte-for-byte raw console captures. The complete console output—including framework deprecation warnings, generated asset listings, and browser screenshots—remains in the R23 acceptance task transcript. No verification was rerun solely to manufacture evidence. Source commit `df632e57a4d8255dcfd5fa1d8ac93aa124164536` is the initial accepted evidence point; the later root-review correction has its own exact command/result summary.

- Fresh isolated test database built from `db/schema.rb`: passed.
- Initial integrated billing, metering, payment, exhaustion, alert, intent, end-to-end and canonical WhatsApp suite at `df632e57`: **101 examples, 0 failures**. See [`backend-tests.log`](backend-tests.log).
- Root-review remediation suite: **105 examples, 0 failures**; focused frontend: **8 tests, 0 failures**; migration rollback/reapply and static checks passed. See [`review-remediation-tests.log`](review-remediation-tests.log).
- Frontend component suite: **8 tests, 0 failures**. ESLint reported **0 problems**. See [`frontend-tests.log`](frontend-tests.log).
- Production Vite build at `df632e57`: **5,080 modules transformed; passed**. See [`production-build.log`](production-build.log). It was not rerun merely to recapture output after the bounded reconciliation/authorization correction; that UI delta has focused Vitest and ESLint coverage in the remediation summary.
- RuboCop across the final R23 Ruby remediation set: **26 files, 0 offenses**.
- Ruby syntax compilation for changed/new Ruby files: passed.
- Rails route recognition for every new billing endpoint: passed.
- Forward upgrade migration from the candidate schema through `2026_09_12_000300`: passed, including the database-level non-overlap constraint for cost periods. See [`migration.log`](migration.log).
- Real in-app browser verification covered desktop and 390×844 mobile layouts, active usage, exhaustion, renewal, a synthetic top-up request, and an idempotent platform confirmation. See [`browser-acceptance/README.md`](browser-acceptance/README.md). Captured desktop/mobile images are retained in the acceptance task transcript.
- English locale JSON parse and Vue script syntax parse: passed.
- `git diff --check`: passed.
- Independent specification and standards reviews were completed repeatedly before commit. All reported P1/P2 items were remediated and rechecked.
- Evidence artifact checksums and source provenance are recorded in [`EVIDENCE_MANIFEST.md`](EVIDENCE_MANIFEST.md).

## Deliberate limitations

- No live payment, provider, Meta, WhatsApp, deployment, push, merge, or issue-closing action was performed.
- Provider costs remain incomplete when any provider usage lacks cost evidence. Contribution margin is complete only when all required operating-cost categories exactly cover the current subscription period and all values are comparable in USD.
- Full historical migration replay remains blocked before R23 by pre-existing migration `20231211010807` (`ActsAsTaggableOn::Taggable::Cache` is unavailable in that historical runtime). The supported forward upgrade from the pinned candidate schema passed.
