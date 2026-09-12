# R21 verification manifest

This manifest records the exact source revisions and commands used for the
release checks. It is intentionally explicit about which checks ran before the
final runtime-isolation patch and which ran afterward.

## Source revisions

| Revision | Meaning |
| --- | --- |
| `e97b1f8bed27824068cc9ae92bccf61cb6de661f` | coordinator-approved baseline |
| `6a1dd7e381cf4b847e205ae02675530997045b29` | implementation commit used for the broad suite, frontend tests/build, and browser run |
| `e8c974ec94886fc143e1c7defae4bac7270eed62` | final source; adds account-scoped runtime admission and the legacy-row regression |

## Commands and outcomes

| Source | Exact command | Outcome |
| --- | --- | --- |
| `6a1dd7e3` | `bundle exec rspec spec/models/ai_lead_employee/ai_provider_connection_spec.rb spec/controllers/platform/api/v1/ai_provider_connections_controller_spec.rb spec/requests/api/v1/accounts/ai_provider_connections_controller_spec.rb spec/requests/ai_lead_employee/ai_provider_delivery_controls_spec.rb spec/requests/ai_lead_employee/ai_provider_usage_controls_spec.rb spec/requests/ai_lead_employee/end_to_end_canonical_launch_proof_spec.rb` | 37 examples, 0 failures |
| `6a1dd7e3` | `bundle exec rspec spec/requests/whatsapp_outbound_delivery_spec.rb spec/requests/whatsapp_outbound_concurrency_spec.rb spec/requests/whatsapp_outbound_crash_spec.rb` | 58 examples, 0 failures |
| `e8c974ec` | `POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=55535 POSTGRES_DATABASE=ale_r21_test POSTGRES_USERNAME=ghalyasaid RAILS_ENV=test ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=... ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=... ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=... bundle exec rspec spec/requests/ai_lead_employee/ai_provider_usage_controls_spec.rb` | 11 examples, 0 failures |
| `6a1dd7e3` | `pnpm exec vitest run app/javascript/dashboard/routes/dashboard/owned/specs/AiProviderSettingsPage.spec.js app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OwnedSettingsLayout.spec.js app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/WhatsappConnectionPage.spec.js` | 12 tests, 0 failures |
| `6a1dd7e3` | `pnpm eslint` | 0 errors; existing warnings only |
| `e8c974ec` | `bundle exec rubocop` on changed Ruby files | no offenses |
| `6a1dd7e3` | `RAILS_ENV=production NODE_OPTIONS=--max-old-space-size=6144 pnpm exec vite build` | passed; 5,078 modules |
| `e8c974ec` | `git diff e97b1f8...HEAD --check` | passed |
| `e8c974ec` | `graft build --only-dir app --only-dir lib --only-dir config --only-dir spec --no-gitignore --no-ignore` | 4,224 files, 20,468 nodes, 34,883 edges |

The focused post-patch suite used synthetic encryption keys and an isolated
PostgreSQL instance. The exact key values are intentionally omitted; they were
placeholders and never represented provider credentials.

## Browser evidence

The in-app browser run used `6a1dd7e3`, disposable database
`ale_release_r21_browser`, production Vite assets, and ports 3215/55535/6435.
The admin observation, member redirect, redaction checks, 401 response, and
console result are recorded in [acceptance.md](acceptance.md). No screenshot or
raw browser log file was retained. Phone acceptance remains pending because the
in-app surface exposes no viewport emulation or resize capability.

## Hashes

| Artifact | SHA-256 |
| --- | --- |
| [acceptance.md](acceptance.md) | `1e8c5e9c45d91dfca0d78b56184550c5041764fc749c37f325d45034b16bf72d` (before this manifest update) |
| [provider-authority-migration.md](provider-authority-migration.md) | `e85d0ba3da8ce45398786224d69068c534c71092006b5dcfb0290adc417e1706` |
| `public/vite/.vite/manifest.json` | `6292f4859c7952c82492b3215c93daaa423a75d8a9be3dfd293cde1e9fbdd6ba` |

The manifest's own hash is computed after committing this evidence update and
reported in the coordinator handoff.
