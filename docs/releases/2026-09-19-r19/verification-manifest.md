# R19 Business setup verification — 19 September 2026

## Provenance

- Branch: `codex/r19-business-setup`
- Baseline: `e531463c5c784d36a6a0f887c2a511c614b878fd`
- Disposable database: `ale_r19_review_f337_20260919_spec`
- Migration: `20260919001000_create_business_setup_sources.rb`

## Exact baseline migration proof

The disposable database was created from `git show HEAD:db/schema.rb`, where
`HEAD` is the baseline above, then migrated with:

```text
RAILS_ENV=test POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=5432 \
POSTGRES_USERNAME=ghalyasaid POSTGRES_DATABASE=ale_r19_review_f337_20260919_spec \
bundle exec rails db:migrate:up VERSION=20260919001000
```

Result: exit 0. `schema_migrations` contains `20260919001000` and
`to_regclass('public.business_setup_sources')` returns
`business_setup_sources`.

Running every historical migration from an empty database remains blocked before
R19 at `20231211010807_add_cached_labels_list.rb` with
`NameError: uninitialized constant ActsAsTaggableOn::Taggable::Cache`. This is a
baseline historical-migration incompatibility; it is not hidden by the exact
baseline-schema migration proof above.

## Focused verification

## Final acceptance corrections

- The setup extractor now treats a statement such as “a sales call requires
  confirmed fit” as an owner clarification, not as a circular question for a
  Lead. A concrete requirement produces a plain Lead-facing prompt instead.
- Explicit English or Swahili no-qualification wording publishes the source's
  qualification mode as `disabled` and generates no rules or questions.
- The setup-preview UI presents localized status, mode, next-step, purpose, and
  rule summaries; it does not expose persisted enum values or generated field
  keys.
- Published setups can be edited as a new proposed review while the current
  published source remains active. The UI exposes each source's revision bodies,
  and Test Center feedback reports a localized orchestration block explanation
  or missing answer evidence instead of calling every completed run successful.
- Regression checks for those changes: focused request cases 2 examples, 0
  failures; complete setup-source request spec 59 examples, 0 failures; Offer
  settings Vitest 18 tests, 0 failures; scoped RuboCop 0 offenses; scoped ESLint
  0 errors.
- Final production build:
  `NODE_OPTIONS=--max-old-space-size=4096 ./node_modules/.bin/vite build --mode production`.
  Exit 0; 5,087 modules transformed; built in 5m 01s. Existing Browserslist
  freshness and large-chunk warnings were unchanged.

## Synthetic browser harness proof

On the isolated test database `ale_r19_browser_final_20260919`, the ignored
local harness uses an active synthetic provider connection and a no-network
client. The guarded proof at `local/r19-browser/proof.rb` produced an unblocked
setup answer with a verified published Knowledge Document source reference and
`sender_invoked: false`; its sensitive-question path produced an open Human
Review Request with the same no-send assertion. A synthetic replacement source
was published through the normal source proposal/publication model path only
because an earlier guarded Offer normalization had made all preexisting
published fixtures stale; their rows and histories remain retained.

The broad counts below were completed on the immediately preceding acceptance
candidate. The final review corrections add bilingual commercial claim
classification, generated-rule replacement, persisted-draft reopen and
transactional sandbox membership admission. Their static checks are current.

- Final focused Business Setup parser and request regression: 71 examples, 0
  failures on the disposable database above. This covers grouped numeric amounts
  (`TZS 50,000`, `$1,250.00`, and `Sh250,000`), revenue-named services, exact
  supported Swahili compounds, whole-span unsupported monetary quarantine,
  phrase-bounded Offer identity, shared-price conflict preservation,
  subject-aware non-Offer and ambiguous charge handling, and draft/published
  source-ownership replacement, order-independent mixed
  Offer-price/financial-metric quarantine, exact Offer-name overlap handling,
  and generic one-token financial-name controls.
- Final affected sandbox runtime: 11 examples, 0 failures, against the
  disposable database above.
- Final real PostgreSQL concurrency regression: 3 examples, 0 failures, with
  explicit R19 task-owned-database truncation authorization. This includes
  publication/review serialization, stable no-send sandbox execution and
  administrator-membership revocation serialization.
- Final Offer settings Vitest: 16 tests, 0 failures. Existing Browserslist,
  Vue i18n-registration and RouterLink-resolution warnings did not fail tests.

- Combined RSpec setup API and sandbox runtime: 23 examples, 0 failures. This
  includes typed prose proposals, R20 price isolation, non-price retrieval,
  future-price withholding, superseded source authority, exact entered
  questions, corrected inbound retrieval, stale admission and no-send behavior.
- Real PostgreSQL lock regression: 2 examples, 0 failures, on the explicitly
  opted-in disposable database. It proves setup publication serializes with a
  Knowledge review writer and sandbox execution holds its source, Offer and
  Knowledge revision stable while a concurrent Offer writer waits.
- Offer settings Vitest: 15 tests, 0 failures, including truthful failed-run UI
  and clearing per-source results when switching Offers.
- RuboCop: scoped Ruby files, 0 offenses.
- ESLint: 0 errors; one existing dynamic i18n-key warning.
- Production build:
  `NODE_OPTIONS=--max-old-space-size=4096 ./node_modules/.bin/vite build --mode production`.
  Exit 0; 5,087 modules transformed; built in 12m 41s. Existing Browserslist
  freshness and large-chunk warnings were unchanged.

Commercial sentences are retained in the immutable source and R20 proposal
history but stripped from published Knowledge Document content; only a current
published commercial revision can answer a price question. Publishing a newer
setup archives the older setup Knowledge Document.

All provider responses in runtime tests were bounded fakes. The sandbox retained
`enqueue_deliveries: false`, rolled simulated records back, and did not construct
the Meta WhatsApp client or enqueue `SendReplyJob`.

## Remaining acceptance

- In-app browser acceptance at phone and desktop widths.
- End-to-end human-help interaction from the guided setup shortcut.
- Final independent diff review after coordinator rebases this staged snapshot
  onto the integrated R12 baseline.

No live customer, paid provider, WhatsApp send, deployment, push, issue closure,
or canonical integration was performed.
