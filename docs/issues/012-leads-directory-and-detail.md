# Leads Directory and Detail

Status: Integration verification

## What to build

Create Leads as the complete unique-Lead directory across all Lead Quality
levels. The completed slice must let operators search, filter, page, inspect,
edit, import, export, and open conversations for Leads while preserving tenant
scope and the distinction between Lead Quality, Follow-up State, Control State,
and Inbox Conversation Status.

## Reference screen

- Leads directory:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-92db24dc-b7da-480f-8702-447ebc3433bc.png`

## Acceptance criteria

- [x] Leads top-level navigation opens the complete unique-Lead directory, not a
      Hot Leads-only queue or generic Community Edition contacts page.
- [x] Search works by Lead name, WhatsApp phone number, business name, and
      supported message/conversation text.
- [x] Quality count chips work for All, Highly Qualified, Qualified, Low
      Qualified, Unqualified, and Unknown, with counts sourced from tenant data.
- [x] Filters work for assignee, source, Follow-up State, booking status, and
      more filters; applied filter state survives pagination and browser
      navigation.
- [x] The table supports row selection, stable selected state, sorting where
      supported, pagination, bulk-selection visual state, and dense columns for
      Lead, Business, Lead Quality, score, source, assignee, last contact, next
      action, and booking.
- [x] The right detail panel shows contact channels, location, Qualification,
      score, why the Lead matters, strongest evidence, missing signals,
      conversation summary, owner, Follow-up State, next action, due time, and
      actions to open conversation or edit Lead.
- [x] Edit Lead supports permitted human-editable extracted fields, validates
      phone and required fields, records audit history, and recomputes
      qualification when edited evidence changes.
- [x] Import and export actions are present and connected to the owned Lead data
      shape; failures and partial imports have visible states.
- [x] Every link, tab-like quality chip, form, filter, dropdown, toggle, table
      control, and action introduced or touched by Leads is keyboard-reachable,
      has a visible state, and routes or persists through existing Rails/Vue
      conventions.
- [x] Admins can see all tenant Leads; Human Operators see only Leads permitted
      by assigned ownership or policy.
- [x] Realistic states include at least 100 Leads across all quality chips,
      selected row, empty filtered result, failed load, long names, missing
      business fields, no booking, booked demo, and scheduled follow-up.
- [x] Rails request/model/service specs cover unique Lead identity, filters,
      authorization, import/export payloads, edit/audit behavior, and
      qualification recomputation triggers.
- [x] Vue tests cover filter chips, dropdown filters, selected detail panel,
      edit form validation, import/export controls, pagination, empty state, and
      long-text truncation.
- [x] Playwright checks cover searching, filtering by each visible category,
      selecting a Lead, editing a Lead, opening its conversation, importing,
      exporting, and mobile access from the bottom nav.
- [x] A same-viewport screenshot at 1487 x 1058 is compared with the reference
      and documented as faithful within the visual tolerances; mobile table and
      detail behavior are checked at 852 x 1846 and 390 px widths.
- [x] `docs/issues/012/design-qa.md` exists with `Result: Passed`, screenshots,
      viewport dimensions, zero-overlap notes, and accepted deviations.

## Acceptance evidence

- Rails specs:
  `POSTGRES_USERNAME=ghalyasaid bundle exec rspec spec/services/ai_lead_employee/leads_directory_service_spec.rb spec/services/ai_lead_employee/lead_update_service_spec.rb spec/requests/api/v1/accounts/leads_spec.rb`
  - 16 examples, 0 failures.
- Ruby lint:
  `RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bundle exec rubocop app/controllers/api/v1/accounts/leads_controller.rb app/services/ai_lead_employee/leads_directory_service.rb app/services/ai_lead_employee/lead_update_service.rb spec/requests/api/v1/accounts/leads_spec.rb spec/services/ai_lead_employee/leads_directory_service_spec.rb spec/services/ai_lead_employee/lead_update_service_spec.rb`
  - 6 files inspected, no offenses.
- Frontend tests:
  `pnpm test app/javascript/dashboard/api/specs/leads.spec.js app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js`
  - 2 files, 11 tests passed.
- Frontend lint:
  `pnpm exec eslint app/javascript/dashboard/api/leads.js app/javascript/dashboard/api/specs/leads.spec.js app/javascript/dashboard/routes/dashboard/owned/LeadsDirectoryPage.vue app/javascript/dashboard/routes/dashboard/owned/LeadDetail.vue app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js`
  - No errors.
- Locale JSON:
  `node -e "JSON.parse(require('fs').readFileSync('app/javascript/dashboard/i18n/locale/en/aiLeadEmployee.json','utf8')); console.log('JSON OK')"`
  - JSON OK.
- Production build:
  `NODE_OPTIONS=--max-old-space-size=4096 pnpm exec vite build`
  - Built successfully; existing Browserslist and large chunk warnings only.
- Browser QA:
  - Codex in-app browser only, with Redis on port 6379, Rails using
    `POSTGRES_USERNAME=ghalyasaid`, and Vite using
    `VITE_RUBY_HOST=127.0.0.1`.
  - Desktop 1487 x 1058: 48 recorded steps, 0 errors.
  - Mobile 390 px: 32 recorded steps, 0 errors.
  - Mobile/tablet 852 x 1846: 2 recorded steps, 0 errors.
  - Post-review spot check:
    `docs/issues/012/screenshots/post-review-browser-qa.json`
    confirmed the final contact channels, conversation status/control state,
    page-level bulk selection, live conversation/booking links, i18n labels, and
    refreshed same-viewport screenshots.

## Blocked by

- Ticket 008: Operational dashboard and team access.
- Ticket 010: Conversation Cockpit navigation and responsive shell.
