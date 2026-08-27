# Ticket 014 Design QA

Result: Passed
Final result: passed

## Source Of Truth

- Approved Documents-first Knowledge reference:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-b1c96520-7552-441c-bb87-ba0a100c6f61.png`
- Rendered app route:
  `http://127.0.0.1:3000/app/accounts/7/knowledge`
- Desktop app capture:
  `docs/issues/014/screenshots/desktop-knowledge-final-1536x1024.png`
- Intermediate mobile app capture:
  `docs/issues/014/screenshots/mobile-knowledge-final-852x1846.png`
- Narrow mobile app capture:
  `docs/issues/014/screenshots/mobile-knowledge-final-390x844.png`

## Viewports

- Desktop DOM viewport: `innerWidth=1536`, `innerHeight=1024`,
  `docWidth=1536`, horizontal overflow `0`.
- Intermediate mobile DOM viewport: `innerWidth=852`, `innerHeight=1846`,
  `docWidth=852`, horizontal overflow `0`.
- Narrow mobile DOM viewport: `innerWidth=390`, `innerHeight=844`,
  `docWidth=390`, horizontal overflow `0`.

## Browser QA

- Browser QA was performed only in the Codex in-app browser.
- Documents covered the full 1,983-character Online Profits document body,
  document list selection, editor controls, preview, publish grouping, Import
  document, New document, WhatsApp AI access toggles, sensitive-claim controls,
  and document testing.
- Approved Answers covered conflict warnings and selected answer details.
- Needs Review covered the filter, linked conversation, answer field, proposal
  fields, Resolve, and Reject.
- At 390 px, both Import document and New document are fully visible and
  reachable, and Documents, Approved Answers, and Needs Review are fully visible
  and reachable.

## Visual Review

- P0: none.
- P1: none.
- P2: none remaining after pass.
- The final layout preserves the approved reference structure: unframed
  full-width workspace, header actions, underline tabs, three-column Documents
  composition, selected-row left accent, compact editor toolbar, and real toggle
  switches.
- Accepted product-data deviations: live tenant account 7 uses seeded
  Online Profits QA records rather than static mock content, while preserving
  the reference information architecture and visual density.

## Verification

- `POSTGRES_USERNAME=ghalyasaid bundle exec rspec spec/models/knowledge_document_spec.rb spec/requests/api/v1/accounts/knowledge_documents_controller_spec.rb spec/controllers/api/v1/accounts/knowledge_items_controller_spec.rb spec/requests/api/v1/accounts/human_review_requests_controller_spec.rb spec/services/ai_lead_employee/knowledge_answer_service_spec.rb`
- `pnpm test app/javascript/dashboard/routes/dashboard/owned/specs/KnowledgeItemsPanel.spec.js`
- `RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bundle exec rubocop app/models/knowledge_document.rb app/controllers/api/v1/accounts/knowledge_documents_controller.rb app/controllers/api/v1/accounts/knowledge_items_controller.rb app/controllers/api/v1/accounts/human_review_requests_controller.rb app/models/knowledge_item.rb app/models/human_review_request.rb app/services/ai_lead_employee/knowledge_answer_service.rb spec/models/knowledge_document_spec.rb spec/requests/api/v1/accounts/knowledge_documents_controller_spec.rb spec/controllers/api/v1/accounts/knowledge_items_controller_spec.rb spec/requests/api/v1/accounts/human_review_requests_controller_spec.rb spec/services/ai_lead_employee/knowledge_answer_service_spec.rb`
- `./node_modules/.bin/eslint app/javascript/dashboard/routes/dashboard/owned/KnowledgeItemsPanel.vue app/javascript/dashboard/routes/dashboard/owned/specs/KnowledgeItemsPanel.spec.js app/javascript/dashboard/api/knowledgeDocuments.js app/javascript/dashboard/api/humanReviewRequests.js app/javascript/dashboard/routes/dashboard/owned/OwnedWorkspacePage.vue`
- `node -e "JSON.parse(require('fs').readFileSync('app/javascript/dashboard/i18n/locale/en/aiLeadEmployee.json','utf8'))"`
- `NODE_OPTIONS=--max-old-space-size=6144 RAILS_ENV=production NODE_ENV=production pnpm exec vite build --config vite.config.ts`
