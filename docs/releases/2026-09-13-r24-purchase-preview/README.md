# R24 exact purchase preview — candidate evidence

Ticket: [R24 / issue 40](https://github.com/drsaidsaid/ai-chatbot/issues/40)

Integrated blocker baseline: `c4b286899cf0ffbbfc4fb1f693dba202ef9af5c2`

Verified source candidate: `6d10530c449b203cd3603a1d68e5db9b4e8dcc89`

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
  customer reviewed. Its signature includes the complete displayed unit-price
  comparison identity, configured prices and allowances, computed unit prices,
  and savings percentage. If usage, entitlement state, or the comparison plan
  changes, the request fails safely and requires a fresh preview.
- The R23 manual confirmation boundary remains the entitlement writer. Confirmed
  payment evidence is now read-only after creation, including actor, reference,
  amount, currency and purpose.
- Payment confirmation holds locks in Account, current finance-authorised
  Platform App, current Subscription, then Request order. Validation, immutable
  confirmation evidence and entitlement mutation all use that same locked
  subscription row.
- A renewal paid before its boundary prepays the current plan's next cycle. An
  upgrade while that future cycle is prepaid is intentionally unsupported and
  blocked until monthly credits renew; the API and customer UI return a stable,
  actionable wait-until-renewal result.
- Expired subscriptions preserve unused purchased extras while AI replies remain
  paused pending manually confirmed renewal. No automatic charge, downgrade,
  refund or dispute action is implied.

## Verification

The original candidate's database-backed checks and allocated browser run used
only the dedicated local database `ale_r24_6056_20260913_spec`, which was dropped
and verified absent after that acceptance pass.

The correction suite used only a fresh dedicated local database
`ale_r24_6056_20260913_fix_spec`, with role `ghalyasaid`. Schema loading and the
non-transactional concurrency fixture are guarded by exact database-name checks
and explicit opt-ins (`R24_DB_OPT_IN=yes` and `R24_LOCKING_FIXTURES=yes`).
Synthetic test-only Active Record encryption values were supplied. No shared
`chatwoot_test` database or destructive committed-fixture cleanup was used. The
same exact-name-guarded database was used for the final allocated browser pass,
then dropped; its absence was verified against PostgreSQL's database catalogue.

- Corrected focused Rails suite: **60 examples, 0 failures**. It covers exact
  preview and tenant isolation, stale signed preview, immutable payment evidence,
  duplicate confirmation and rollback inherited from R23, multiple upgrades, allowance
  carry-forward, usage/upgrade, renewal/upgrade and usage/renewal concurrency,
  displayed-comparison signature invalidation, the prepaid-cycle upgrade guard,
  and a deterministic database-barrier proof of confirmation/rollover locking.
- Corrected affected Vue suite: **11 tests, 0 failures**. It covers
  desktop/phone-fluid layout primitives, preview-before-request, exact
  money/difference/balance, locale/timezone date rendering, computed savings, preserved-extra guidance,
  and the wait-until-renewal action.
- Bounded follow-up request suite: **17 examples, 0 failures**. The added
  regression first failed with the generic request error, then passed after the
  typed prepaid-cycle result was preserved through request creation. It covers
  upgrade preview, intervening early renewal payment, and upgrade request.
- Changed Ruby files: focused RuboCop checks passed with no offences.
- Changed JavaScript/Vue files: focused ESLint checks passed with no errors.
- Production Vite build at exact source
  `6d10530c449b203cd3603a1d68e5db9b4e8dcc89`: **5,085 modules transformed;
  passed in 42.42 seconds**. Advisory output was limited to the existing stale
  Browserslist data and large bundle chunks.
- `git diff --check`, Ruby syntax checks and English locale JSON parsing passed.
- The normal repository pre-commit hook passed for every source commit.

## Independent diff audit

Standards and ticket-contract reviews were run independently against the fixed
baseline. The first correction pass removed server-formatted English dates from
the customer flow, returned stable API error codes, enforced read-only payment
evidence, covered usage-versus-renewal concurrency, and excluded non-upgrade plans
from comparisons. The follow-up review identified three P1 gaps; this candidate
closes them with the single lock scope, the explicit prepaid-cycle product guard,
and a complete signed comparison snapshot described above. Remaining smell notes
about purpose strings and serializer reuse are non-blocking refactoring
opportunities within the existing R23 domain.

The subsequent specification review found one presentation-path residual: when
an early renewal was confirmed after an upgrade preview, request creation safely
blocked the upgrade but collapsed the typed result to a generic error. This
candidate preserves that typed result through `RequestService` and the request
controller, so both preview-time and request-time rejection produce the same
stable wait-until-renewal action used by the existing UI.

## Browser acceptance

The prior candidate's allocated in-app browser pass ran against a test-only Rails
environment on `127.0.0.1:5050` with test mail/jobs, synthetic data and outbound
HTTP forced to a dead loopback endpoint. Screenshots were captured in the task at
the default desktop viewport and at exactly **390 × 844**; the temporary viewport was reset
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

That historical browser evidence is retained for traceability. After independent
review cleared the corrected source, a targeted final in-app browser pass ran at
exact source `6d10530c449b203cd3603a1d68e5db9b4e8dcc89`:

- At the default **1280 × 720** viewport, the base Growth upgrade preview rendered
  **TZS 150,000.00**, balance **12 → 32** (`30 monthly + 2 purchased extras`),
  account-local renewal time, the exact price equation and computed **44.4%**
  per-credit savings.
- With that preview open, the fixture moved to a prepaid future cycle. Continuing
  exercised the stale-preview request path and showed: “A future month is already
  paid on your current plan. Upgrade after your monthly credits renew, or contact
  platform support.” Database verification showed **zero upgrade requests, zero
  total requests and zero confirmations**, so payment instructions were never
  created and no entitlement changed.
- Cancelling and selecting Growth again exercised preview-time rejection and
  showed the same actionable message. At exactly **390 × 844**, it remained
  readable and the page measured `390px` content width with `390px` scroll width.
- Returning the fixture to its current-cycle state and selecting Growth again at
  **390 × 844** restored the complete base preview and cleared the rejection
  message, proving UI recovery.
- Browser logs contained no errors. Warnings were limited to an initial unmatched
  `/app/` route, existing deprecated Modal `onClose` usage and Lit development
  mode. The viewport was reset, the tab closed, both local services stopped, and
  their listening ports verified clear.
