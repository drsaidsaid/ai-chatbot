# R03 — Direct WhatsApp setup and durable receiving

Ticket: [#20](https://github.com/drsaidsaid/ai-chatbot/issues/20). Parent #16 and
ticket #20 remain open for coordinator review and integration.

Base: `5577a37ddae5f6d08b33b0b33aefe6d933d7003c` (integrated R01/R02).
Branch: `codex/r03-whatsapp-ingress-20260910`.
Implementation commit: `cf83fd9b097fd62d37eff8ca5b66b5fa33543662`.
Review correction commit: `7511872fa4e5de33b72b6849aa10f2021fef2c4e`.
Latest correction checks and source hashes: [review corrections](review-corrections/README.md).
Decision: [ADR 0009](../../adr/0009-verified-whatsapp-receipts-and-recovery.md).
The frozen September 9 audit evidence, approved completion plan, MIT notice and
enterprise source are unchanged.

## Delivered path

An administrator opens Settings → WhatsApp connection, enters the Meta number,
number ID, Business Account ID, access token and app secret, and saves. The
server registers and verifies the callback and saves provider health. Reload
retains identifiers and shows configured indicators while credential inputs
remain empty. One Cloud connection per Business Account is enforced by both
Rails and PostgreSQL. Members cannot read or change this connection resource.
The retained native Cloud form also requires the signing secret and returns to
the same connection screen; its old finish route no longer depends on reflecting
a verification token into the browser.

The canonical `/webhooks/whatsapp/:phone_number` route verifies exact raw bytes
against every entry/change's resolved channel, validates the envelope, and
commits an encrypted receipt plus immutable routing bindings before HTTP 200.
It queues only the receipt ID. Normalization records logical events, correct
sender identity and provider time, then commits CE Conversation/Message records
and eligible AI intents within database locks. A recurring job recovers queued
work after a queue outage, rollback or process crash. Media download failure
leaves the event retryable rather than silently accepting a missing attachment.

Delivery history is retained separately from the Message's current status.
Late sent/failed updates cannot regress delivered/read. An update arriving before
its outgoing provider ID is stored waits for correlation. Failures exposed to
the administrator are classified codes with recovery guidance. The status screen
counts unexpanded receipts as waiting work, distinguishes receipt time from
message processing time, and requires affirmative connected/verified health
before reporting readiness for a first message.

## Browser evidence

The **in-app browser**, task-owned tab 1, exercised the real Rails/Vue app at
`http://127.0.0.1:3213`. Test-mode Vite assets used port 3093. This was not a
mocked UI or an evaluation sandbox. The seed created only a synthetic
administrator and Business Account; setup created the actual WhatsApp channel.
The loopback provider at port 3214 performed a real GET verification challenge,
then sent a raw-body HMAC-signed POST to the canonical callback. The controlled
runner invoked the same production job on the accepted receipt, because Rails'
test queue does not run workers automatically.

- Desktop 1440 × 1000: empty setup, save, reload with empty credential fields,
  provider failure, and the persisted Conversation after a full reload.
- Phone 390 × 844: saved setup, receiving status and the same Conversation.
- First callback: one receipt, one processed event, one incoming Message and one
  Conversation. A second envelope carrying the same provider message ID left
  **two receipts, one event, one Message and one Conversation**.
- No browser console errors were recorded. A transient Offline banner during
  development reload is visible in the saved-phone screenshot; the subsequent
  receiving and conversation captures show the live page after reconnection.
- These screenshots were captured during implementation. The early provider
  error capture shows the general recovery text; final source adds a specific
  classified reason beneath it. The final receiving/conversation behavior is
  unchanged. The production build was checked separately.

Screenshot files are genuine JPEGs. `screenshot-manifest.json` records verified
byte format, dimensions and SHA-256; the extension is not used to infer format.
The adjacent text snapshots preserve visible state, and
`browser-console-errors.json` records the browser result. Original implementation
source hashes are recorded independently in `runtime-source-sha256.json`; the
correction evidence above pins the updated source separately.

No production credentials, Meta test assets, live customer, AI provider or
calendar service was used. The browser Business Account has no live AI launch
approval. An isolated database test uses synthetic reviewed evaluation fixtures
to test durable AI-intent queue recovery; it does not invoke the AI job or a
provider. Actual Meta delivery and supervised customer tests remain a later
proof using explicitly authorized test assets.

## Verification

Final command results and counts are in `checks.json` and `evidence/`. Exported
text logs remove trailing whitespace and extra blank lines at EOF;
`evidence-log-manifest.json` records raw-output and exported-file hashes.
The regression selection includes canonical controller/job receiving, Cloud
service and channel behavior, provider setup/health, orchestration recording,
and the retained end-to-end launch proof. Existing greeting assertions still
verify one greeting and one pending intent; the test deliberately runs ingress
and greeting jobs without evaluating later AI behavior owned by other tickets.

The new request checks cover secret encryption/reflection, one connection,
admin-only setup, signature rejection, complete batch routing, tenant binding,
raw replay, queue outage, monotonic delivery history, late correlation, alternate
recipient identifiers, malformed envelopes and media retry. Database recovery
checks run outside transactional fixtures, use independent connections and force
first-Conversation races. The crash check starts a separate Ruby worker, pauses
its transaction after Message insertion, kills the worker, terminates only that
recorded PostgreSQL session to release the artificial pause, then recovers the
receipt. Startup is bounded at 90 seconds for loaded CI hosts. It never kills a
shared database/server process. Run this group serially against its disposable
test database; it truncates its own fixtures before/after each example.

## Reproduce locally

Follow the [R01 runbook](../2026-09-09-r01/runbook.md) for fresh pinned dependencies
and an isolated PostgreSQL/Redis cluster. This task used Ruby 3.4.4, Bundler
2.5.16, Node 24.13.0, pnpm 10.2.0, PostgreSQL 18 and Redis 8, with newly installed
dependencies. Do not copy another worktree's environment or database. Set
synthetic Active Record encryption keys before creating or migrating credentials.

R03 ports: PostgreSQL 55483, Redis 6393, Rails 3213, Vite 3093 and fake Meta 3214.
Databases: `ale_release_r03_spec`, `ale_release_r03_browser`,
`ale_release_r03_upgrade` and `ale_release_r03_current`. All are disposable and
owned by this task. The private `tmp/release.env` is ignored. Choose free ports
and adapt the loopback fixture when reproducing concurrently.

```sh
# Load the private synthetic environment from the R01 setup.
set -a
. tmp/release.env
set +a

# Empty browser database only; the fixture refuses to replace existing records.
POSTGRES_DATABASE=ale_release_r03_browser bundle exec rails db:create db:schema:load db:migrate
POSTGRES_DATABASE=ale_release_r03_browser bundle exec rails runner script/release/whatsapp/seed_browser.rb
node script/release/whatsapp/fake_meta.mjs
# In separate terminals with the same exported environment:
POSTGRES_DATABASE=ale_release_r03_browser WHATSAPP_CLOUD_BASE_URL=http://127.0.0.1:3214 \
  bundle exec rails server -b 127.0.0.1 -p 3213
pnpm exec vite --host 127.0.0.1 --port 3093 --mode test
```

Sign in as `release-operator@example.test` with the synthetic password selected
in the private environment. On WhatsApp connection use `+255700000003`, phone ID
`3003`, Business Account ID `9003`, token `r03-access-secret` and app secret
`r03-signing-secret`. The fake provider binds only to loopback and refuses a
callback outside its configured local Rails port. It is test tooling, not a
production provider replacement.

```sh
# Emit one signed fake callback. Repeat to exercise logical replay.
curl -sS -X POST http://127.0.0.1:3214/_test/deliver
POSTGRES_DATABASE=ale_release_r03_browser bundle exec rails runner \
  'Whatsapp::WebhookReceipt.where(expanded_at: nil).find_each { |receipt| Webhooks::WhatsappEventsJob.perform_now(receipt.id) }'
# Set fail=true, click Check connection, then restore fail=false and check again.
curl -sS -X POST -H 'Content-Type: application/json' --data '{"fail":true}' \
  http://127.0.0.1:3214/_test/health
```

Use the Inbox to inspect Amina's persisted message and reload. Close only the
task-owned browser tab and stop only its own local processes after the proof.
The production environment must leave `WHATSAPP_CLOUD_BASE_URL` unset for Meta.

## Schema and credential upgrade

Migrations `20260910000300` through `20260910000304` encrypt existing credential
keys and legacy plaintext business-management tokens, enforce one Cloud connection, create durable receipt/event tables, preserve
provider message time and persist connection health. The current-schema load and
the pre-R01 checkpoint upgrade must produce equivalent full schemas, including
CE triggers. Use the R01 comparator; do not ignore missing trigger definitions.

```sh
git show f1bf3cd0604ae610baa675061b0e76dcd49fffcd:db/schema.rb > tmp/release/checkpoint-upgrade.rb
POSTGRES_DATABASE=ale_release_r03_upgrade SCHEMA=tmp/release/checkpoint-upgrade.rb \
  bundle exec rails db:create db:schema:load
POSTGRES_DATABASE=ale_release_r03_upgrade bundle exec rails runner script/release/whatsapp/seed_legacy.rb
POSTGRES_DATABASE=ale_release_r03_upgrade SCHEMA=tmp/release/checkpoint-upgrade.rb \
  bundle exec rails db:migrate db:schema:dump
POSTGRES_DATABASE=ale_release_r03_upgrade bundle exec rails runner script/release/whatsapp/verify_upgrade.rb
cp db/schema.rb tmp/release/current-schema.rb
POSTGRES_DATABASE=ale_release_r03_current SCHEMA=tmp/release/current-schema.rb \
  bundle exec rails db:create db:schema:load db:migrate db:schema:dump
ruby script/release/compare_schema.rb tmp/release/checkpoint-upgrade.rb tmp/release/current-schema.rb
```

The upgrade fixture is synthetic and deliberately predates encryption. Its
verification reads the encrypted row after reload and exercises the exact unique
index migration against two conflicting rows within a rolled-back transaction.
Neither row may be deleted to make migration succeed. Deployments must resolve
existing duplicate Cloud connections explicitly before promotion. Credential
migration rollback is intentionally refused; restore a verified backup under
R18's deployment procedure. Preserve the encryption keys with that backup.

## R04 and integration handoff

- Keep the canonical receipt-ID job boundary and channel-scoped event identity.
  Legacy raw-hash job handling remains for already queued CE jobs; current HTTP
  ingress always accepts a verified receipt. Do not enqueue a raw callback from
  a new public route.
- Use `Message.provider_created_at` and the durable event's provider time for
  the customer response window. Receipt and processing times describe our work,
  not when the customer spoke. Treat missing/invalid provider time conservatively.
- Set the outgoing provider ID on the owned Message for delivery correlation.
  Early statuses remain `awaiting_message` and recovery can project them later.
  Preserve the monotonic delivered/read projection and immutable event history.
- Durable AI intents are committed with normalization, then queued after commit.
  Recovery also enqueues pending intents. R04 owns outbound send claims,
  ambiguous provider acceptance and post-commit outbound/greeting queue recovery;
  do not treat an enqueue acknowledgement as a customer delivery confirmation.
- R06 is changing member InboxPolicy/index/show and realtime payloads. Preserve
  its minimal member inbox payload and assigned-conversation composer access.
  R03's connection API and native health/registration actions are administrator
  only; admin-safe provider configuration belongs in the full admin payload.
- Incoming media uses the encrypted server Meta token, not dashboard cookies or
  an Attachment download URL. Outbound Cloud delivery currently consumes
  `Attachment#download_url`; R04 must preserve a distinct server-delivery
  capability when integrating R06's authenticated media access.
- Each event holds a PostgreSQL channel lock through normalization/media fetch.
  This is a deliberate V1 correctness tradeoff documented in ADR 0009. Recovery
  queues, oldest pending age, failures and receipt retention need R18's operating
  checks. No live launch or supervised provider proof is claimed here.
