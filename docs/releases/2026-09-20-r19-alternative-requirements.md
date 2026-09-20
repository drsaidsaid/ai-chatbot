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
# 70 examples, 0 failures

./node_modules/.bin/vitest run \
  app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OfferConfigurationPanel.spec.js
# 20 tests passed

bundle exec rubocop <scoped changed Ruby files>
# 0 offenses

./node_modules/.bin/eslint <Offer panel and focused spec>
# 0 errors; existing dynamic/raw i18n warnings only
```

No full build, browser runtime, deployment, provider call, publication, or live
send was run.
