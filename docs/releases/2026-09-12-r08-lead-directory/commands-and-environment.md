# Commands and environment

## Isolated services

- PostgreSQL 18.6: `127.0.0.1:55533`
- Database: `ale_r08_directory_test`
- Redis: `redis://127.0.0.1:6433/0`
- Reserved app port: `3233` (never started)
- Final state: all three ports released

Rails checks used `RAILS_ENV=test`, explicit PostgreSQL and Redis variables, a throwaway 64-character `SECRET_KEY_BASE`, and throwaway 64-character Active Record encryption primary, deterministic and derivation keys. `BUNDLE_PATH`, `GEM_HOME`, and `GEM_PATH` were unset so the repository runtime selected its configured gems. Secret values are intentionally omitted because only their presence and length affect these tests.

## Final focused invocations

```text
bundle exec rspec spec/requests/api/v1/accounts/leads_spec.rb spec/services/ai_lead_employee/leads_directory_service_spec.rb
pnpm exec vitest run app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js app/javascript/dashboard/api/specs/leads.spec.js --reporter=dot
pnpm eslint app/javascript/dashboard/routes/dashboard/owned/LeadsDirectoryPage.vue app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js app/javascript/dashboard/api/leads.js app/javascript/dashboard/api/specs/leads.spec.js
bundle exec rubocop app/controllers/api/v1/accounts/leads_controller.rb app/services/ai_lead_employee/lead_import_service.rb app/services/ai_lead_employee/leads_directory_service.rb app/services/ai_lead_employee/lead_update_service.rb spec/requests/api/v1/accounts/leads_spec.rb spec/services/ai_lead_employee/leads_directory_service_spec.rb
NODE_OPTIONS=--max-old-space-size=4096 pnpm exec vite build
git diff --check
```

Results: 21 Rails examples and 18 frontend tests passed with zero failures. The six changed Ruby files passed RuboCop. Frontend lint exited zero; the package wrapper scanned the existing application and reported 507 existing warnings and zero errors. The production bundle transformed 5,078 modules and completed in 49.43 seconds with existing chunk-size warnings.

The final Rails log was captured after the signed preview-token change and is the closest test attribution to source commit `b690343e`. The final frontend tests, lint and build were captured before that Ruby-only token refinement; their covered frontend blobs are identical to the source commit. No claim is made that a whole-tree hash was recorded at each earlier test instant.

