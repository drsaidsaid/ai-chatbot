# R17 pilot-control review repair evidence

## Scope

This repair keeps the general Launch Gate paused. It adds no platform permission record, live pilot authorization, provider call, WhatsApp send, deployment, or frontend build.

## Checks run

- `bundle exec rails zeitwerk:check` — passed (`All is good!`).
- Focused RuboCop over the changed implementation, migration, and regression-spec files — passed with no offenses.
- Historical `db:migrate` replay is blocked by the unrelated 2023 `ActsAsTaggableOn::Taggable::Cache` migration incompatibility. The isolated database was created from the repository schema (version `20260920000100`), then the R17 hardening migration `20260920000200` applied successfully.
- The focused suite below passed on isolated local PostgreSQL: **35 examples, 0 failures**.

## Executed focused suite

```sh
RAILS_ENV=test POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=5432 \
POSTGRES_USERNAME=ghalyasaid POSTGRES_DATABASE=ai_chatbot_r17_pilot_control_test \
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=r17-review-primary-placeholder \
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=r17-review-deterministic-placeholder \
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=r17-review-salt-placeholder \
bundle exec rspec spec/requests/platform/pilot_authorizations_spec.rb \
  spec/services/ai_lead_employee/pilot_authorization_activator_spec.rb \
  spec/services/ai_lead_employee/ai_provider/metered_client_pilot_admission_spec.rb \
  spec/services/ai_lead_employee/pilot_dispatch_authority_spec.rb \
  spec/services/ai_lead_employee/orchestration_intent_recorder_spec.rb \
  spec/services/ai_lead_employee/highly_qualified_handoff_service_spec.rb
```

The test set covers owner-approval input, activation permission/key-revision drift, exact persisted intent scope, failed-attempt cost uncertainty, preservation of an operator stop, final known-cost dispatch, intent recording, and handoff-alert suppression.

The relevant existing PostgreSQL concurrency controls also passed:

```sh
RAILS_ENV=test POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=5432 \
POSTGRES_USERNAME=ghalyasaid POSTGRES_DATABASE=ai_chatbot_r17_pilot_control_test \
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=r17-review-primary-placeholder \
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=r17-review-deterministic-placeholder \
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=r17-review-salt-placeholder \
bundle exec rspec spec/requests/ai_lead_employee/ai_provider_usage_controls_spec.rb
```

Result: **11 examples, 0 failures**.
