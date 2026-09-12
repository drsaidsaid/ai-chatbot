# R21 verification manifest

This manifest records the source revisions, commands, retained output, and
failed exploratory attempts used for the release checks.

## Source revisions

| Revision | Meaning |
| --- | --- |
| `e97b1f8bed27824068cc9ae92bccf61cb6de661f` | coordinator-approved baseline |
| `6a1dd7e381cf4b847e205ae02675530997045b29` | implementation commit used for frontend tests and production build |
| `e8c974ec94886fc143e1c7defae4bac7270eed62` | final source; adds account-scoped runtime admission and the legacy-row regression |
| `59ca179cb988ce47c9e60b6e45cc7e35029a898f` | docs-only tip before this final evidence run; runtime tree equals `e8c974ec` |

## Commands and outcomes

| Source | Exact command | Outcome |
| --- | --- | --- |
| `e8c974ec` | `POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=55535 POSTGRES_DATABASE=ale_r21_test POSTGRES_USERNAME=ghalyasaid REDIS_URL=redis://127.0.0.1:6435/0 RAILS_ENV=test ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=r21-final-primary-placeholder ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=r21-final-deterministic-placeholder ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=r21-final-salt-placeholder bundle exec rspec spec/models/ai_lead_employee/ai_provider_connection_spec.rb spec/models/ai_lead_employee/ai_provider_usage_spec.rb spec/controllers/platform/api/v1/ai_provider_connections_controller_spec.rb spec/requests/api/v1/accounts/ai_provider_connections_controller_spec.rb spec/requests/ai_lead_employee/ai_provider_delivery_controls_spec.rb spec/requests/ai_lead_employee/ai_provider_usage_controls_spec.rb spec/requests/ai_lead_employee/end_to_end_canonical_launch_proof_spec.rb spec/requests/whatsapp_outbound_delivery_spec.rb` | 85 examples, 0 failures; [`rails-r21-final.log`](evidence/raw/rails-r21-final.log) |
| `6a1dd7e3` | `pnpm exec vitest run app/javascript/dashboard/routes/dashboard/owned/specs/AiProviderSettingsPage.spec.js app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OwnedSettingsLayout.spec.js app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/WhatsappConnectionPage.spec.js` | 12 tests, 0 failures |
| `6a1dd7e3` | `pnpm eslint` | 0 errors; existing warnings only |
| `e8c974ec` | `bundle exec rubocop` on changed Ruby files | no offenses |
| `6a1dd7e3` | `RAILS_ENV=production NODE_OPTIONS=--max-old-space-size=6144 pnpm exec vite build` | passed; 5,078 modules |
| `e8c974ec` | `git diff e97b1f8...HEAD --check` | passed |
| `e8c974ec` | `graft build --only-dir app --only-dir lib --only-dir config --only-dir spec --no-gitignore --no-ignore` | 4,224 files, 20,468 nodes, 34,883 edges |

The final Rails suite used synthetic encryption keys and isolated PostgreSQL
and Redis instances. These values are placeholders and never represented
provider credentials.

The retained [`source-equivalence.log`](evidence/raw/source-equivalence.log)
records exit 0 for both checks: frontend source is identical from `6a1dd7e3` to
`e8c974ec`, and runtime source is identical from `e8c974ec` to the docs-only
branch tip. It also records the production Vite manifest hash.

## Retained failed attempts

- [`rails-combined-final.log`](evidence/raw/rails-combined-final.log) records an
  initial zero-example invocation with an incorrect historical filename.
- [`rails-combined-final-corrected.log`](evidence/raw/rails-combined-final-corrected.log)
  records 90 examples and one failure after unrelated legacy WhatsApp recovery
  specs were added to the R21 set. The independently retained
  [`rails-whatsapp-concurrency-example.log`](evidence/raw/rails-whatsapp-concurrency-example.log)
  reproduces that pre-existing test-fixture failure: the legacy test does not
  create the provider connection now required by `ReportBuilder`. These files
  are outside the R21-changed spec set and were not used as acceptance evidence.
- [`browser-fixture.log`](evidence/raw/browser-fixture.log) records a discarded
  setup attempt where unqualified `dropdb` and `createdb` were unavailable and
  the shell continued. `browser-fixture-corrected.log` used absolute PostgreSQL
  binary paths with fail-fast execution and is the accepted fixture record.

## Browser evidence

The final in-app browser run used runtime source `e8c974ec`, disposable database
`ale_release_r21_browser`, production Vite assets, and ports 3215/55535/6435.
Desktop and 390 x 844 phone observations, member redirect, redaction checks,
and console results are retained in
[`browser-observations.json`](evidence/browser-observations.json). The raw 401
response is [`platform-unauthorized.http`](evidence/raw/platform-unauthorized.http).
Screenshots were captured and visually inspected in the browser transcript;
the browser tool did not expose a local screenshot export.

The disposable fixture was recreated with the PostgreSQL 18 `dropdb` and
`createdb` binaries, followed by these application commands:

```text
POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=55535 POSTGRES_DATABASE=ale_release_r21_browser POSTGRES_USERNAME=ghalyasaid REDIS_URL=redis://127.0.0.1:6435/0 RAILS_ENV=test ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=r21-final-primary-placeholder ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=r21-final-deterministic-placeholder ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=r21-final-salt-placeholder bundle exec rails db:schema:load
POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=55535 POSTGRES_DATABASE=ale_release_r21_browser POSTGRES_USERNAME=ghalyasaid REDIS_URL=redis://127.0.0.1:6435/0 RAILS_ENV=test RELEASE_ADMIN_PASSWORD=<synthetic-local-password> ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=r21-final-primary-placeholder ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=r21-final-deterministic-placeholder ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=r21-final-salt-placeholder bundle exec rails runner script/release/r21_seed_synthetic.rb
POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=55535 POSTGRES_DATABASE=ale_release_r21_browser POSTGRES_USERNAME=ghalyasaid REDIS_URL=redis://127.0.0.1:6435/1 RAILS_ENV=test ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=r21-final-primary-placeholder ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=r21-final-deterministic-placeholder ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=r21-final-salt-placeholder bundle exec rails runner script/release/r21_browser_server.rb
```

The placeholder password is omitted from committed evidence even though it was
valid only for the disposable local database. The corrected fixture output is
[`browser-fixture-corrected.log`](evidence/raw/browser-fixture-corrected.log),
and server output is [`browser-server.log`](evidence/raw/browser-server.log).

## Artifact integrity

SHA-256 hashes for the release documents, observations, and every retained raw
artifact are stored in [`evidence/SHA256SUMS`](evidence/SHA256SUMS). The built
Vite manifest hash is retained separately in `source-equivalence.log` because
the generated build directory is intentionally not committed.
