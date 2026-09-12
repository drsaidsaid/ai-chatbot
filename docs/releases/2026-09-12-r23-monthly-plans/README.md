# R23 monthly plans and logical AI reply metering

Date: 2026-09-12  
Branch: `codex/r23-monthly-plans`  
Approved base: `58aaf41115a5d52e7566187b99defde6ba80da2a`

## Demonstrated path

- Platform finance operators can publish immutable, versioned monthly plans and confirm an approved manual payment exactly once.
- Business Account administrators can request a new subscription, renewal, fixed approved top-up, or same-currency upgrade, but cannot confirm payment.
- A confirmation revalidates the plan, subscription status, and entitlement snapshot under lock so stale or reordered requests cannot change an entitlement.
- Customer-facing AI work reserves one unit before calling the model. A logical reply settles once only after all registered WhatsApp delivery parts have canonical acceptance evidence.
- Failed sends release the unit; unknown or partially accepted multi-part sends remain reserved for conservative reconciliation. An authorised retry reuses the released logical-reply record.
- Calendar-month rollover uses the Business Account reporting timezone and renewal anchor. Unpaid renewal or exhausted allowance pauses AI while preserving inbound capture and the human inbox.
- Exhaustion and renewal alerts are durable, visible in Billing, and queued to configured Business Account owner WhatsApp recipients without consuming an AI reply. Alert retries reuse the same message.
- Billing displays subscription usage separately from Meta messaging and advertising charges. Platform reporting separates revenue by currency and marks provider-cost and margin completeness honestly.

## Verification evidence

- Fresh isolated test database built from `db/schema.rb`: passed.
- Focused billing, metering, payment, exhaustion, alert and intent suite: **28 examples, 0 failures**.
- Existing orchestration accounting-failure and end-to-end canonical launch proofs: **8 examples, 0 failures**.
- RuboCop across all 38 changed/new Ruby files, excluding generated `db/schema.rb`: **0 offenses**.
- Ruby syntax compilation for changed/new Ruby files: passed.
- Rails route recognition for every new billing endpoint: passed.
- English locale JSON parse and Vue script syntax parse: passed.
- `git diff --check`: passed.
- Independent specification and standards reviews were completed before commit. Their P1 findings—finance-role provisioning, archived-plan mutability, stale payment confirmation, actual alert dispatch authority, and retry safety—were remediated and rechecked.

## Deliberate limitations

- No live payment, provider, Meta, WhatsApp, deployment, push, merge, or issue-closing action was performed.
- Frontend Vitest, the production build, and an in-app browser capture were not run because this worktree has no `node_modules` and the shared dependency-heavy lane was occupied by another release. The Vue changes received static syntax, locale, component-spec, and review coverage; the coordinator should run the queued frontend command and browser proof once that lane is available.
- Provider costs are reported only when actual provider usage records contain cost evidence. Operating-cost allocation is out of scope, so the API does not claim a complete margin.
