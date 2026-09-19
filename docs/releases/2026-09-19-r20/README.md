# R20 Offer commercial facts evidence

## Provenance

- Ticket: `docs/v1-alignment-2026-09-12/r20.md`
- Integrated baseline: `e859008345fc3e38e55f293ea6e439bac5698e1a`
- Isolated branch: `codex/r20-offer-pricing`
- Community Edition Rails/Vue paths only; no `enterprise/` code, provider call, live message, deployment or live price seed.

## Implemented path

- Admins save Offer commercial facts as an inactive draft and explicitly publish an immutable revision.
- Published facts include fixed amount/currency or quote-required mode, effective window and timezone, conditions, promotion window/conditions/eligibility confirmation, and an approved HTTP(S) pricing or purchase link.
- Offer-scoped document imports create reviewable proposals. Conflicts remain proposals, never overwrite the published revision, and approval populates only the inactive draft.
- Lead budgets remain qualification evidence and platform subscription prices remain in the subscription domain; extraction excludes those contexts.
- Preview and inbound pricing questions use `AiLeadEmployee::OfferPricingResolver`.
- The outbound Offer context preserves the commercial revision and pricing variant. Final WhatsApp admission rejects a changed revision, expired/future price, or promotion boundary crossed while queued.
- Offer and document APIs remain admin-only and account-scoped. The Offer settings UI uses responsive one/two-column layouts and explicit draft/published language.

## Verification run

- Ruby syntax: passed for every added/changed Ruby implementation file.
- JavaScript syntax: passed for the Offer API, Offer settings component script, Knowledge component script and focused component spec.
- Locale JSON parse: passed.
- Rails route inspection: passed for draft, publish, preview and proposal-review endpoints.
- Isolated PostgreSQL schema prepare: passed first against task-owned `ai_lead_r20_test`, then against fresh guarded `ai_lead_r20_review_test` after integrity hardening. The fresh load includes scoped account/Offer/document/term/revision composite foreign keys.
- Focused RSpec after both root review rounds: 51 examples, 0 failures across database integrity, commercial-term requests, document proposals, pricing authority, stale final-send checks and promotion eligibility.
- Focused Vitest: 12 examples, 0 failures for the Offer settings component, including explicit commercial-term save/publish and clearing a displayed preview after a newer revision is published.
- Focused RuboCop: 23 changed Ruby/spec files, no offenses.
- Direct ESLint on the four changed JavaScript/Vue files: no errors. Existing style/i18n warnings remain in the previously warning-bearing panels.
- `git diff --check`: passed.
- Pure Rails runtime check: exact `USD 1250.50` normalization and `Africa/Dar_es_Salaam` 09:00 → 06:00 UTC conversion passed, with local-time round trip.
- Direct production Vite build: passed after the final UI correction (`5087` modules transformed; existing chunk-size and Browserslist warnings only). Raw output is in `vite-production-build.log`.
- Guarded browser acceptance used a synthetic `RAILS_ENV=test` database and local-only Redis. Desktop exercised fixed-price draft/publish, unpublished-draft isolation, document conflict review, proposal approval, explicit republish and quote-required mode. A 390×844 viewport had no horizontal overflow and persisted state after reload.

## Review corrections

- Existing drafts require an expected version, and proposal approval merges only proposed commercial fields into the current locked draft, preventing stale overwrites.
- The published revision is validated and database-constrained to the same account, Offer and commercial-term record.
- Conditional promotion eligibility comes only from current typed evidence for the selected account Offer.
- Authored document updates and imports create proposals transactionally; standard and promotional facts can be proposed together without replacing published authority.
- Offer pricing questions exclude Lead budgets, revenue/salary, platform plans/subscriptions, AI reply credits, Meta charges and ad-spend contexts.
- Equivalent human amounts such as `1250` and `1250.00` do not create false conflicts; materially different standard or promotional amounts do.

## Review correction red/green record

- Root's red audit of the pre-correction staged candidate identified five blocking behaviors: broad plan/budget routing could return stale knowledge; promotion eligibility was neither freshness-limited nor re-read at final send; extraction collapsed contradictory candidates; cross-currency promotion approval could silently redenominate a standard amount; and independent foreign keys allowed invalid direct-write joins.
- Regression examples for all five behaviors were added before their implementation corrections. Runtime execution was held by the shared-lane coordinator, so the first permitted execution was the combined green run rather than separate executable red and green runs.
- Green command used `RAILS_ENV=test`, `POSTGRES_HOST=localhost`, and exact task-owned `POSTGRES_DATABASE=ai_lead_r20_review_test`; final result: 51 examples, 0 failures in 7 focused spec files.
- Database examples use bulk inserts intentionally to bypass Rails validations and prove PostgreSQL itself rejects cross-account Offer terms, revisions and proposals.
- Final spec re-review added two executable red examples against commit `fabaaadc`: mixed course/platform wording returned no authoritative Offer price, and two prices in one sentence produced a pending proposal. The targeted red run was 2 examples, 2 failures; after correction it was 2 examples, 0 failures, and the complete focused suite was 51 examples, 0 failures.
- Browser review found that a previously displayed preview remained visible after publishing a newer revision. The focused UI regression failed first (1 example, 1 failure), then passed after publication began clearing the stale preview; the complete component suite passed with 12 examples. The explanatory copy now states that preview reflects only the current published price and that document suggestions never publish automatically.

## Limitations

- The conservative V1 document extractor handles explicit price/cost/fee/promotion/quote language with supported currencies. It deliberately does not infer prices from unlabeled numbers or Lead budget, revenue, platform subscription, Meta charge or ad-spend text.
