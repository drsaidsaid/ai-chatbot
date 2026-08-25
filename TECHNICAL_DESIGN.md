# AI Lead Employee Technical Design

**Status:** Draft approved for v1 implementation planning  
**Product requirements:** `PRODUCT_REQUIREMENTS.md`  
**Architecture decision:** `docs/adr/0001-chatwoot-as-inbox-boundary.md`  

## 1. System Boundary

Chatwoot Community Edition supplies official channel connectivity, the shared inbox, contacts, conversations, messages, attachments, human replies, private notes, labels, teams, assignments, priorities, and operational notifications.

AI Lead Employee supplies the business-specific intelligence and workflow: qualification, evidence, conversation control, knowledge approval, booking, alerts, follow-up, audit, and evaluations.

Chatwoot data is accessed through a dedicated adapter. Product domain code must not call Chatwoot APIs directly.

```text
Lead
  |
  v
Meta WhatsApp Cloud API
  |
  v
Chatwoot CE <---- Human Operator
  |
  | signed webhook events
  v
Chatwoot Adapter
  |
  v
AI Lead Employee API + Worker
  |          |           |           |
  v          v           v           v
Postgres   AI model   Calendar   Alert delivery
```

## 2. Runtime Stack

### Chatwoot

- Vue 3 frontend built with Vite and Tailwind CSS.
- Ruby 3.4 and Rails 7.2 backend served by Puma.
- Rails Action Cable for real-time browser updates.
- Sidekiq workers and Sidekiq Cron.
- PostgreSQL 16 with pgvector.
- Redis for queues, caching, and Action Cable.
- Rails Active Storage backed by local disk in development and S3-compatible storage in production.

### AI Lead Employee

- Next.js and TypeScript for the admin dashboard and embedded Chatwoot Dashboard App.
- A TypeScript API and background worker for webhook ingestion, AI orchestration, scheduling, and alerts.
- PostgreSQL as the authoritative application store.
- Redis-backed jobs for immediate processing, with durable job intent recorded in PostgreSQL.
- OpenAI-compatible model adapter so the model provider is replaceable.
- A calendar adapter, with Google Calendar as the current leading candidate but not a locked provider decision.

The first deployment may share one PostgreSQL server and one Redis server with Chatwoot, but each application must use separate databases, credentials, key prefixes, backups, and migrations.

## 3. Production Services

1. HTTPS reverse proxy and public domain.
2. Chatwoot Rails web service.
3. Chatwoot Sidekiq worker.
4. AI Lead Employee web/API service.
5. AI Lead Employee background worker.
6. PostgreSQL with separate Chatwoot and AI Lead Employee databases.
7. Redis with isolated namespaces or databases.
8. S3-compatible attachment storage.
9. SMTP provider for account and operational email.
10. Meta WhatsApp Cloud API connection.
11. AI model provider.
12. Google Calendar OAuth connection.
13. Monitoring, error reporting, database backups, and restore verification.

## 4. Feature Preservation

The pinned Chatwoot source under `upstream/chatwoot` is treated as read-only upstream. Community Edition modules that are outside v1 remain in the source and are hidden through account feature flags, inbox configuration, or navigation. This includes later channels, Help Center, campaigns, CSAT, website chat, contact segments, and optional integrations.

Production uses the versioned Community Edition image, not an image containing Chatwoot Enterprise code. A narrow Chatwoot patch is allowed only after an integration test proves that supported extension points cannot satisfy a required behavior.

## 5. State Mapping

Lead Quality, Follow-up State, Control State, and Chatwoot Conversation Status are independent.

| Product meaning | Authoritative state | Chatwoot representation |
|---|---|---|
| AI may reply | Control State = `ai_active` | Conversation usually `pending`, assigned to AgentBot |
| Human requested | Control State = `handoff_requested` | Bot handoff event; conversation becomes `open` |
| Human owns replies | Control State = `human_active` | Conversation `open`, assigned to Human Operator |
| AI manually paused | Control State = `ai_paused` | Conversation remains operationally open or pending; product attribute records pause |
| Follow-up scheduled | Follow-up State plus scheduled action | Conversation may be `snoozed` until due |
| Conversation finished | Control State = `closed` | Conversation `resolved` |
| Lead is hot | Lead Quality = `highly_qualified` | Mirrored label/custom attribute and urgent priority |

A human-authored outgoing message always transitions Control State to `human_active`. Only an explicit resume command may return it to `ai_active`.

## 6. Draft PostgreSQL Schema

All primary keys are UUIDs unless the table stores an external identifier. Every tenant-owned table includes `business_account_id`. Timestamps use UTC; business display and booking rules use the Business Account timezone.

### Tenancy and Access

#### `business_accounts`

- `id`, `name`, `timezone`, `status`.
- `chatwoot_account_id` for the current adapter.
- Unique: `chatwoot_account_id` when present.

#### `users`

- `id`, `email`, `name`, `status`, authentication metadata.
- A person may belong to multiple Business Accounts later.

#### `business_account_memberships`

- `business_account_id`, `user_id`, `role`, `chatwoot_user_id`.
- Roles in v1: `admin`, `team_member`.
- Unique: `(business_account_id, user_id)` and `(business_account_id, chatwoot_user_id)` when present.

#### `integration_connections`

- `business_account_id`, `provider`, `status`, external account identifiers, encrypted secret reference, scopes, expiry, and health metadata.
- Provider categories initially: `chatwoot`, `ai_model`, and `calendar`; the concrete AI and calendar providers remain replaceable.
- Raw secrets must never be returned to the browser or written to logs.

### Offer and Qualification Configuration

#### `offers`

- `business_account_id`, `name`, `description`, `currency`, approved price range, `active`.

#### `qualification_questions`

- `business_account_id`, `offer_id`, stable `key`, prompt, position, answer type, options JSON, `required_for_highly_qualified`, `enabled`.
- Unique: `(offer_id, key)` and `(offer_id, position)` for enabled questions.

#### `qualification_rules`

- `business_account_id`, `offer_id`, `kind`, field, operator, comparison value JSON, score delta, forced outcome, priority, `enabled`.
- `kind` is `hard_rule` or `score_rule`; a hard rule overrides the numerical score.

### Leads and Conversations

#### `leads`

- `business_account_id`, normalized `primary_phone_e164`, name, email, business name, business type, location.
- Source, campaign, Meta referral metadata, opt-out timestamp, assigned membership, and last-contact timestamps.
- Unique: `(business_account_id, primary_phone_e164)` for the WhatsApp MVP.

#### `lead_qualifications`

- `business_account_id`, `lead_id`, `offer_id`, Lead Quality, score, reasons JSON, missing signals JSON, version, evaluated timestamp.
- Normalized problem, lead volume, urgency, budget range, decision authority, and readiness fields.
- Unique active qualification: `(lead_id, offer_id)`.

#### `qualification_evidence`

- `business_account_id`, `lead_qualification_id`, signal key, normalized value JSON, confidence, source message, source type, recorded by, and superseded timestamp.
- Source types: `lead_message`, `human_edit`, `import`, `system_rule`.
- Highly Qualified decisions must reference current evidence for pain, budget, urgency, and decision authority.

#### `conversations`

- `business_account_id`, `lead_id`, channel, external inbox ID, external conversation ID, Control State, Follow-up State, current question key, question debt, last activity timestamps, and current Human Operator.
- Unique: `(business_account_id, channel, external_conversation_id)`.

#### `messages`

- `business_account_id`, `conversation_id`, channel, external message ID, direction, actor type, text or media metadata, delivery state, occurred timestamp, and content hash.
- Actor types: `lead`, `ai_employee`, `human_operator`, `system`.
- Unique: `(business_account_id, channel, external_message_id)`.
- Message content follows the configured retention policy; secrets and unnecessary raw webhook data are excluded.

### Knowledge and Human Review

#### `knowledge_documents`

- `business_account_id`, optional `offer_id`, category, title, source type, content or storage reference, authority priority, version, status, and approval metadata.
- Categories: `faq`, `offer`, `pricing`, `objection`, `policy`, `supporting`.

#### `knowledge_items`

- `business_account_id`, document ID, canonical question, approved answer, tags, version, status, approval metadata, and optional embedding.
- Only `approved` items may be used in a lead-facing answer.

#### `review_requests`

- `business_account_id`, conversation ID, triggering message ID, type, priority, question, status, assigned membership, resolution, resolved message ID, and timestamps.
- Types include unknown answer, conflicting knowledge, sensitive topic, angry lead, and blocking qualified lead.

### Booking, Follow-Up, and Alerts

#### `availability_rules`

- `business_account_id`, calendar connection, timezone, permitted weekdays, local start/end times, duration, buffer, minimum notice, and `enabled`.

#### `bookings`

- `business_account_id`, lead ID, conversation ID, qualification ID, provider, external event ID, start/end UTC, timezone, status, lead email, confirmation state, and assigned membership.
- Unique: `(business_account_id, provider, external_event_id)`.
- A database exclusion or transactional availability check must prevent overlapping active bookings for the same calendar.

#### `follow_up_policies`

- `business_account_id`, optional offer ID, trigger stage, delay, maximum attempts, message strategy, and `enabled`.

#### `scheduled_actions`

- `business_account_id`, conversation ID, action type, run time, status, attempt count, idempotency key, cancellation reason, and result metadata.
- Unique: `idempotency_key`.

#### `alert_routes`

- `business_account_id`, alert type, recipient membership or phone number, channel, priority threshold, and `enabled`.

#### `alerts`

- `business_account_id`, route ID, related entity type and ID, rendered summary, delivery state, external message ID, attempts, and timestamps.
- One logical alert uses one stable idempotency key even when delivery is retried.

### Reliability, Audit, and Evaluation

#### `webhook_events`

- `business_account_id`, provider, external event ID, payload hash, event type, received timestamp, processing state, attempts, and sanitized error.
- Unique: `(business_account_id, provider, external_event_id)` when supplied; otherwise use a deterministic tenant-scoped payload-derived key.

#### `audit_events`

- `business_account_id`, actor type and ID, action, entity type and ID, before JSON, after JSON, correlation ID, and occurred timestamp.
- Append-only. Corrections create new events rather than rewriting history.

#### `evaluation_scenarios`

- `business_account_id`, name, transcript fixture, expected qualification, expected next action, risk tags, and status.

#### `evaluation_runs`

- `business_account_id`, scenario ID, configuration version, model identifier, actual output, grader results, reviewer decision, and timestamps.

#### `outbox_events`

- `business_account_id`, event type, aggregate type and ID, payload, idempotency key, state, attempts, and timestamps.
- Database changes and required side effects are committed together; workers deliver outbox events to Chatwoot, calendar, and alert adapters.

## 7. Chatwoot Mapping

The adapter stores these stable links:

- Business Account -> Chatwoot account.
- Channel connection -> Chatwoot inbox.
- Lead -> Chatwoot contact.
- Conversation -> Chatwoot conversation.
- Message -> Chatwoot message.
- Human Operator -> Chatwoot user/agent.

Mirrored Chatwoot custom attributes should initially include:

- `lead_quality`.
- `qualification_score`.
- `business_type`.
- `problem_summary`.
- `urgency`.
- `budget_range`.
- `decision_authority`.
- `lead_source`.
- `booking_status`.
- `control_state`.

Mirrored labels should initially include `hot-lead`, `needs-review`, `follow-up-due`, and `call-booked`. Mirroring failures must not change the authoritative product state and must be retried through the outbox.

## 8. Event Processing Invariants

1. Verify the Chatwoot webhook signature before accepting an event.
2. Store and deduplicate the webhook before running AI logic.
3. Serialize processing per Conversation.
4. Re-read Control State immediately before sending an AI reply.
5. Persist the AI decision, outbound message intent, and outbox event in one database transaction.
6. Send through Chatwoot using an idempotency key where supported and reconcile the external message ID.
7. A human reply invalidates pending AI reply and follow-up jobs.
8. Booking and alert creation are idempotent and retryable.
9. Every Lead Quality transition records evidence, reasons, configuration version, and actor.
10. No cross-tenant query may execute without Business Account scope.

## 9. Security and Operations

- Encrypt integration secrets at rest and rotate them without redeploying the application.
- Use least-privilege Chatwoot and calendar credentials.
- Redact message content and personal data from logs.
- Enforce role and Business Account scope at the API and query layers.
- Back up PostgreSQL and attachment storage, and test restoration.
- Track webhook delay, failed jobs, AI latency, answer refusals, handoffs, bookings, and alert delivery.
- Pin Chatwoot Community Edition and apply upstream security releases promptly.
- Define retention and deletion before onboarding an external client.

## 10. Implementation Order

1. Infrastructure and empty schema migrations.
2. Chatwoot adapter, webhook ingestion, deduplication, and normalized messages.
3. Control State and human takeover safety.
4. Configurable offers, questions, rules, and qualification evidence.
5. Approved knowledge and review requests.
6. Embedded qualification panel and operational queues.
7. Calendar booking and WhatsApp alerts.
8. Follow-up, opt-out, analytics, audit, and CSV import/export.
9. Sandbox, evaluations, launch gate, and controlled pilot.
