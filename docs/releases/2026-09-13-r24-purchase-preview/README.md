# R24 exact purchase preview — candidate evidence

Ticket: [R24 / issue 40](https://github.com/drsaidsaid/ai-chatbot/issues/40)

Integrated blocker baseline: `c4b286899cf0ffbbfc4fb1f693dba202ef9af5c2`

Verified source candidate: `8c97b7a45cc32cf134f25b775f15bec0e751acfd`

Branch: `codex/r24-billing-clarity`

No deployment, live payment, provider call, customer data, WhatsApp send, push,
integration, or issue closure was performed.

## Delivered contract

- A Business Account admin previews a configured top-up or same-currency higher
  plan before creating payment instructions. The preview shows the exact
  two-decimal amount, current usage and balance, resulting monthly and purchased
  balances, and the unchanged account-local renewal time.
- Upgrade price is the full current-cycle target-plan price minus current-plan
  price. Applying the existing finance-authorised confirmation preserves used
  replies, purchased extras and renewal date while replacing included allowance.
- The preview compares per-credit prices only with a plan that is an eligible
  higher-price upgrade. Savings are calculated from configured prices; no fixed
  percentage is advertised.
- A signed 30-minute preview binds a top-up or upgrade request to the balance the
  customer reviewed. If usage or entitlement state changes, the request fails
  safely and requires a fresh preview.
- The R23 manual confirmation boundary remains the entitlement writer. Confirmed
  payment evidence is now read-only after creation, including actor, reference,
  amount, currency and purpose.
- Expired subscriptions preserve unused purchased extras while AI replies remain
  paused pending manually confirmed renewal. No automatic charge, downgrade,
  refund or dispute action is implied.

## Verification

All database-backed checks used only the newly created local database
`ale_r24_6056_20260913_spec`, with role `ghalyasaid`. Schema loading was guarded
by an exact database-name comparison and explicit `R24_DB_OPT_IN=yes`. Synthetic
test-only Active Record encryption values were supplied. No shared
`chatwoot_test` database or destructive committed-fixture cleanup was used.
The dedicated database was reused for the explicitly allocated guarded browser
run only after confirming that it was empty. Every fixture operation repeated
the exact-name and explicit opt-in guards. The database was dropped after
acceptance and its removal was verified against PostgreSQL's database catalogue.

- Focused Rails suite: **56 examples, 0 failures**. It covers exact preview and
  tenant isolation, stale signed preview, immutable payment evidence, duplicate
  confirmation and rollback inherited from R23, multiple upgrades, allowance
  carry-forward, usage/upgrade, renewal/upgrade and usage/renewal concurrency.
- Affected Vue suite: **10 tests, 0 failures**. It covers desktop/phone-fluid
  layout primitives, preview-before-request, exact money/difference/balance,
  locale/timezone date rendering, computed savings and preserved-extra guidance.
- Changed Ruby files: focused RuboCop checks passed with no offences.
- Changed JavaScript/Vue files: focused ESLint checks passed with no errors.
- Production Vite build: **5,085 modules transformed; build completed**. The
  existing advisory warnings were limited to stale Browserslist data and large
  bundle chunks.
- `git diff --check`, Ruby syntax checks and English locale JSON parsing passed.
- The normal repository pre-commit hook passed for every source commit.

## Independent diff audit

Standards and ticket-contract reviews were run independently against the fixed
baseline. The final corrections remove server-formatted English dates from the
customer flow, return stable API error codes instead of raw English domain
messages, document the new endpoint/flow here, enforce read-only payment evidence,
cover usage-versus-renewal concurrency, and exclude non-upgrade plans from savings
comparisons. Remaining smell notes about purpose strings and serializer reuse are
non-blocking refactoring opportunities within the existing R23 domain.

## Browser acceptance

The allocated in-app browser pass ran against a test-only Rails environment on
`127.0.0.1:5050` with test mail/jobs, synthetic data and outbound HTTP forced to
a dead loopback endpoint. Screenshots were captured in the task at the default
desktop viewport and at exactly **390 × 844**; the temporary viewport was reset
and the tab and both local servers were closed afterward.

- Desktop and phone previews both showed grouped two-decimal TZS amounts,
  account-local renewal time, the monthly/purchased balance split, plain-language
  held-reply copy, computed **44.4%** per-credit savings and manual-support copy.
- Top-up preview showed **TZS 75,000.00**, balance **6 → 11** (`2 monthly + 9
  purchased extras`) with two replies awaiting confirmation. Upgrade preview
  showed **TZS 150,000.00**, balance **6 → 26** (`22 monthly + 4 purchased
  extras`) and the exact `250,000.00 − 100,000.00 = 150,000.00` equation.
- A ninth held usage made the open upgrade preview stale. Continuing was safely
  rejected, a fresh preview recovered with balance **5 → 10**, and the database
  still contained **zero payment requests and zero confirmations**. No payment
  instructions were created and no credits were granted.
- The phone viewport measured `390px` content width with `390px` scroll width,
  confirming no horizontal overflow. Browser-console noise was limited to the
  expected Vite development HMR websocket reconnect warning; no application
  runtime failure appeared.
