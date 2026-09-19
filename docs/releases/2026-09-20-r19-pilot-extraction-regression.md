# R19 pilot extraction regression — 20 September 2026

Baseline: `6c5b86590b5e19a9c8b850ad8fa6157893d8e02e`.

The request regression uses the owner-approved Online Profits University pilot
notes verbatim. It verifies that explanatory fit negation does not create a
requirement, sales-call agreement maps to the existing canonical boolean field,
and a disjunctive business/revenue qualification remains an explicit owner
clarification. A revenue threshold is treated as a financial metric, not an
ambiguous programme price.

The same regression also verifies that an unresolved disjunctive qualification
cannot publish a qualification-dependent sales-call setup, even when a legacy
saved proposal lacks the new clarification marker. Answer-only knowledge with
an unrelated missing price remains publishable. Repeated sales-call agreement
sentences produce one canonical question and rule. Reversed revenue-or-business
alternatives are handled equally conservatively. Source correction retires a
generated field only while its saved question and rule values remain unchanged;
an administrator's canonical sales-call agreement edit is preserved and
detached from source ownership.

Verification on isolated test database `ale_r19_final_patch_20260919_spec`:

```text
RAILS_ENV=test POSTGRES_USERNAME=ghalyasaid POSTGRES_DATABASE=ale_r19_final_patch_20260919_spec \
  bundle exec rspec spec/requests/ai_lead_employee/business_setup_sources_spec.rb
# 64 examples, 0 failures

bundle exec rubocop app/models/ai_lead_employee/business_setup_source.rb \
  app/services/ai_lead_employee/business_setup_proposal_extractor.rb \
  app/services/ai_lead_employee/business_setup_qualification_proposal.rb \
  spec/requests/ai_lead_employee/business_setup_sources_spec.rb
# 0 offenses
```

No production build, deployment, paid provider, or live send was run.
