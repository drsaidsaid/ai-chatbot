# R09 configurable qualification final verification

This evidence verifies the approved R09 contract amendment against the frozen source below. The evidence commit is intentionally separate from the source commit.

## Frozen source

- Commit: `1e460bb20de3193c4376faf7b415fe081b63eee3`
- Tree: `36c3d18ba3b5e3d8324d67351e4cfe4a2217a1fd`
- Subject: `Amend R09 for configurable qualification`
- A final `git diff --exit-code` over `app`, `db`, and `spec` against the source commit was clean before this evidence was committed.

## Automated verification

- Amended selected Rails request suite: 69 examples, 0 failures. See [rails-amended-selected.log](rails-amended-selected.log).
- Delivery and configuration concurrency suite: 31 examples, 0 failures. It ran with the required isolated database name and without weakening the race guard. See [rails-delivery-concurrency.log](rails-delivery-concurrency.log).
- Offer configuration Vue suite: 1 file and 8 tests passed. See [vue-offer-configuration.log](vue-offer-configuration.log).
- Focused ESLint: 0 errors and 1 existing dynamic-i18n-key warning. See [eslint-focused.log](eslint-focused.log).
- Focused RuboCop: 20 files inspected, no offenses. See [rubocop-focused.log](rubocop-focused.log).
- The production Vite build had already passed on this exact frozen source in 3 minutes 49 seconds, with only the known caniuse database and chunk-size warnings. It was not rerun after source freeze, as requested.
- The reversible assessment migration had already passed a direct down/up cycle on this exact frozen source.

## Browser acceptance

Fresh acceptance was completed in the Codex in-app browser against the local application and isolated verification database. It covered all amended configuration choices, owner-authored question metadata, the requirement dimension, and save/reload persistence. A follow-up pass used the browser viewport capability at 390 × 844, verified editing and persistence at phone width, and confirmed no horizontal overflow. See [browser-acceptance.md](browser-acceptance.md).

## Integrity

The independent final amendment review is recorded in [final-amendment-code-review.md](final-amendment-code-review.md). It found one blocking P1 contract mismatch, one hard documentation-flow violation, and two non-blocking duplication findings. The later root review identified the repeated-rule overwrite and the fail-open sales-call admission in [root-review-findings.md](root-review-findings.md); its clarified gate supersedes the earlier action-eligibility-only recommendation.

## Initial root correction

The authorised correction preserves every same-field requirement as an order-independent conjunction and makes automated sales-call admission fail closed. Its first gate required canonical met fit/readiness/action assessments, no Unqualified exclusion, and explicit positive boolean `sales_call_agreement` evidence. The existing settings panel exposes that stable boolean field without adding fixed business qualification questions. This section records that historical correction and its checks; the optional-dimension resolution below corrects its overstrict treatment of `not_required`.

- Focused Rails behavior and delivery revisions: 59 examples, 0 failures. See [root-correction-rails.log](root-correction-rails.log).
- Additional amended Offer behavior: 47 examples, 0 failures. See [root-correction-rails-additional.log](root-correction-rails-additional.log).
- Offer authority and configuration concurrency: 11 examples, 0 failures. See [root-correction-concurrency.log](root-correction-concurrency.log).
- Offer settings Vue suite: 1 file, 9 tests passed. See [root-correction-vue.log](root-correction-vue.log).
- Focused RuboCop: 9 files inspected, no offenses. See [root-correction-rubocop.log](root-correction-rubocop.log).
- Focused ESLint: 0 errors and the existing dynamic-i18n-key warning. See [root-correction-eslint.log](root-correction-eslint.log).
- The final two-axis correction review found three test/validation gaps and one metadata-coupling issue; all were resolved before these checks. The remaining manifest-refresh observation is resolved by the checksums below.

## Optional-dimension resolution

Corrected source `50df1a0433de3911e1a39e5d25ad1ef5a63b8b26` requires every configured fit, readiness and action-eligibility prerequisite to be met, while accepting canonical `not_required` only when the current revision-locked Offer has no enabled requirement or enabled required question for that dimension. Full assessment shape validation, hard exclusions and explicit positive `sales_call_agreement` remain mandatory. See [root-optional-dimension-resolution-review.md](root-optional-dimension-resolution-review.md) for the exact source range, red/green result and independent findings.

- Focused qualification, rule, reply-context, revision and admission behavior: 59 examples, 0 failures. See [root-optional-dimension-rails.log](root-optional-dimension-rails.log).
- Focused RuboCop: 3 files inspected, no offenses. See [root-optional-dimension-rubocop.log](root-optional-dimension-rubocop.log).

SHA-256 checksums for the evidence files are recorded in [manifest.sha256](manifest.sha256). The unrelated untracked `graft/` directory was excluded.
