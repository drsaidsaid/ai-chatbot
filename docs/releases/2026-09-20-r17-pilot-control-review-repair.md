# R17 pilot-control review repair evidence

## Scope

This repair keeps the general Launch Gate paused. It adds no platform permission record, live pilot authorization, provider call, WhatsApp send, deployment, or frontend build.

## Checks run

- `bundle exec rails zeitwerk:check` — passed (`All is good!`).
- Focused RuboCop over the 18 changed implementation, migration, and regression-spec files — passed with no offenses.
- `bundle exec rails db:migrate RAILS_ENV=test` — blocked locally before migration execution because PostgreSQL at `localhost:5432` authenticates no `postgres` role. No test database mutation was performed by that failed connection attempt.

## Required focused follow-up once the configured test PostgreSQL service is available

```sh
bundle exec rails db:migrate RAILS_ENV=test
bundle exec rspec spec/requests/platform/pilot_authorizations_spec.rb \
  spec/services/ai_lead_employee/ai_provider/metered_client_pilot_admission_spec.rb \
  spec/services/ai_lead_employee/pilot_dispatch_authority_spec.rb \
  spec/services/ai_lead_employee/orchestration_intent_recorder_spec.rb
```

The test set covers owner-approval input, exact persisted intent scope, failed-attempt cost uncertainty, final known-cost dispatch, and intent recording. Activation configuration-drift and handoff suppression need the same database-backed run before root acceptance.
