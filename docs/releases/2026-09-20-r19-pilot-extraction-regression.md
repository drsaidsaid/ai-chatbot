# R19 pilot extraction regression — 20 September 2026

Baseline: `6c5b86590b5e19a9c8b850ad8fa6157893d8e02e`.

The request regression uses the owner-approved Online Profits University pilot
notes verbatim. It verifies that explanatory fit negation does not create a
requirement, sales-call agreement maps to the existing canonical boolean field,
and a disjunctive business/revenue qualification remains an explicit owner
clarification. A revenue threshold is treated as a financial metric, not an
ambiguous programme price.

Verification on isolated test database `ale_r19_final_patch_20260919_spec`:

```text
bundle exec rspec spec/requests/ai_lead_employee/business_setup_sources_spec.rb
# 60 examples, 0 failures

bundle exec rubocop app/services/ai_lead_employee/business_setup_proposal_extractor.rb \
  app/services/ai_lead_employee/business_setup_qualification_proposal.rb \
  app/services/ai_lead_employee/commercial_claim_classifier.rb \
  spec/requests/ai_lead_employee/business_setup_sources_spec.rb
# 0 offenses
```

No production build, deployment, paid provider, or live send was run.
