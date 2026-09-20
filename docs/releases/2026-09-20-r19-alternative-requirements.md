# R19 pilot alternative requirements

Baseline: `0ce119da2d151c7d59b0febc37c3c026e00920d3`.

The candidate adds bounded typed `all`/`any` Offer requirements, branch-aware
missing questions, dimension-scoped required-question handling, source-owned
field protection for group references, and plain-language owner editing and
preview. Existing flat rules remain conjunctive and unchanged.

Verification on isolated test database `ale_r19_final_patch_20260919_spec`:

```text
bundle exec rspec spec/requests/ai_lead_employee/offer_requirement_groups_spec.rb \
  spec/requests/ai_lead_employee/business_setup_sources_spec.rb
# 77 examples, 0 failures

./node_modules/.bin/vitest run \
  app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OfferConfigurationPanel.spec.js
# 21 tests passed

bundle exec rubocop <scoped changed Ruby files>
# 0 offenses

./node_modules/.bin/eslint <Offer panel and focused spec>
# 0 errors; existing dynamic/raw i18n warnings only
```

No full build, browser runtime, deployment, provider call, publication, or live
send was run.

## Coordinator integrated acceptance

Candidate `84941d51cef2371e86190b5de10ad71c1f04e5a7` was merged without conflicts after source review. Candidate production Vite build passed (5092 modules, 2m06s). No runtime changes were made during integration.

Actual in-app browser tab 17, isolated fixture at 127.0.0.1:3019:

- Any/All switching preserved branches; money Known information → Less than did not crash.
- Desktop save and reload retained a changed money threshold; 390×844 phone editing restored the original test threshold, with readable controls. Temporary viewport reset.
- After restarting the fixture to refresh its cached asset manifest, blank-price Save Offer succeeded (revision 5) and reload retained TZS 950000, without checking Quote required or publishing a price.
- Proposed setup displayed “Less than 950000.00 TZS” and “Equals Yes” with the intended OR/AND structure. No source was published.

The initial post-build browser attempt still served cached assets and failed native price validation; this was not counted as passing. The restarted fixture loaded the corrected form. All fixture records are synthetic; no provider connection, external messages, deployment or live response-quality claims.

Full R17/R18 and the wider V1 programme remain open. This is the accepted R19 pilot follow-up, preserving original R19 acceptance.
