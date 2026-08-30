# AI Lead Employee Technical Design

**Status:** Reconciled planning baseline
**Product requirements:** `PRODUCT_REQUIREMENTS.md`
**Architecture decisions:** `docs/adr/0002-owned-inbox-fork.md`, `docs/adr/0005-canonical-whatsapp-path.md`, `docs/adr/0006-durable-grounded-ai-boundary.md`

## 1. System Boundary

AI Lead Employee is an owned product built from the Chatwoot Community Edition
source. Its inbox, contacts, conversations, messages, attachments, human
replies, notes, labels, teams, assignments, notifications, qualification,
evidence, conversation control, knowledge approval, booking, alerts, follow-up,
audit, and evaluations run inside our application boundary.

The system does not call a Chatwoot service or depend on Chatwoot credentials.
The existing Community Edition WhatsApp channel code is part of this owned
application and is the canonical Meta integration path.

```text
Lead <---- WhatsApp ----> Meta WhatsApp Cloud API
                               |
                               v
              AI Lead Employee (owned CE inbox + durable AI workflow)
                    |          |           |           |
                    v          v           v           v
                Postgres   AI model   Calendar   Alert delivery
```

## 2. Runtime Stack

### Owned Inbox Foundation

- Chatwoot Community Edition's Vue 3 frontend built with Vite and Tailwind CSS,
  renamed and extended as our inbox interface.
- Chatwoot Community Edition's Ruby and Rails backend, renamed and extended as
  our owned backend.
- Rails Action Cable for real-time browser updates.
- Sidekiq workers and Sidekiq Cron.
- Our PostgreSQL 16 database with pgvector.
- Redis for queues, caching, and Action Cable.
- Rails Active Storage backed by local disk in development and S3-compatible storage in production.

### Product Extensions

- First-party AI Orchestration, scheduling, alerts, qualification, booking, and
  knowledge modules inside the owned backend.
- PostgreSQL-backed orchestration intent plus queued workers for automated work
  that must survive retries and re-check Control State.
- OpenAI-compatible model adapter so the model provider is replaceable;
  OpenRouter is the initial configured provider.
- A calendar adapter, with Google Calendar as the current leading candidate but
  not a locked provider decision.

The first deployment uses one application database and Redis namespace under our
control. Upstream code is an implementation foundation, not a separate service.

## 3. Production Services

1. HTTPS reverse proxy and public domain.
2. Owned Rails web service.
3. Owned Sidekiq worker.
4. AI Lead Employee web/API service.
5. AI Lead Employee background worker.
6. PostgreSQL database under our control.
7. Redis with isolated namespaces or databases.
8. S3-compatible attachment storage.
9. SMTP provider for account and operational email.
10. Meta WhatsApp Cloud API connection.
11. AI model provider.
12. Google Calendar OAuth connection.
13. Monitoring, error reporting, database backups, and restore verification.

## 4. Feature Preservation

The pinned Community Edition source is the reviewable upstream baseline. Our owned
fork will retain its MIT notice and exclude enterprise code. Modules outside v1
remain hidden through our configuration or navigation until needed.

The pinned `v4.17.0` Community Edition source is imported at the owned repository
root. Upstream remains a read-only review remote; upgrades are selected, tested,
and merged through a dedicated maintenance branch rather than treated as an
external runtime dependency.

The V1 operator surface is intentionally limited to Inbox, Hot Leads, Leads,
Reviews, Knowledge, Bookings, and owned settings. Other Community Edition
capabilities are retained but hidden until a separate product decision enables
them. `docs/V1_OWNED_INBOX_SCOPE.md` is the authoritative feature boundary.

## 4.1 Current Code Reconciliation

The current branch contains useful Community Edition WhatsApp channel behavior
and later AI Lead Employee experiments, but it is not a coherent V1 baseline.
Planning must treat the following as blockers before feature recovery:

- `Webhooks::WhatsappController`, `Webhooks::WhatsappEventsJob`,
  `Whatsapp::IncomingMessageWhatsappCloudService`, `Message`, `Conversation`,
  and `Whatsapp::SendOnWhatsappService` are the production path to retain and
  extend.
- `Webhooks::Meta::WhatsappController`,
  `Meta::Whatsapp::InboundWebhookProcessor`,
  `Meta::Whatsapp::OutboundMessageSender`, and `Meta::Whatsapp::TextMessageClient`
  duplicate that path and bypass Community Edition behavior. They are donor
  code only until retired or folded into the canonical services.
- The current custom processor calls `AiLeadEmployee::WhatsappAutoReplyService`
  inline after persistence. V1 requires durable AI Orchestration after commit,
  not model or answer decisions inside webhook processing.
- Community Edition already records configured greetings as visible template
  messages through the message-template hook. V1 must coordinate this greeting
  with AI Orchestration rather than replacing it or hiding it.
- Current knowledge and qualification services are deterministic experiments.
  The production AI provider boundary, encrypted admin configuration,
  OpenRouter-compatible calls, Source References, and provider failure
  classification remain unimplemented blockers.

## 5. State Mapping

Lead Quality, Follow-up State, Control State, and Inbox Conversation Status are independent.

| Product meaning       | Authoritative state                   | Owned inbox representation                                                          |
| --------------------- | ------------------------------------- | ----------------------------------------------------------------------------------- |
| AI may reply          | Control State = `ai_active`           | Conversation is eligible for the AI Employee only after final checks                |
| Human requested       | Control State = `handoff_requested`   | Bot handoff event; conversation becomes `open`                                      |
| Human owns replies    | Control State = `human_active`        | Conversation `open`, assigned to Human Operator                                     |
| AI manually paused    | Control State = `ai_paused`           | Conversation remains operationally open or pending; product attribute records pause |
| Follow-up scheduled   | Follow-up State plus scheduled action | Conversation may be `snoozed` until due                                             |
| Conversation finished | Control State = `closed`              | Conversation `resolved`                                                             |
| Lead is hot           | Lead Quality = `highly_qualified`     | Mirrored label/custom attribute and urgent priority                                 |

A human-authored outgoing message always transitions Control State to `human_active`. Only an explicit resume command may return it to `ai_active`.

### Control State Transitions

| Current state                      | Event                           | Next state          | Required side effect                                                                               |
| ---------------------------------- | ------------------------------- | ------------------- | -------------------------------------------------------------------------------------------------- |
| `ai_active`                        | AI requests a human             | `handoff_requested` | Clear AI ownership, cancel pending AI replies, open the owned inbox Conversation                   |
| `ai_active` or `handoff_requested` | Human assigned or human replies | `human_active`      | Assign the Human Operator and cancel pending AI replies and automatic follow-ups                   |
| Any non-closed state               | Human pauses AI                 | `ai_paused`         | Cancel pending AI replies and automatic follow-ups                                                 |
| `human_active` or `ai_paused`      | Human explicitly resumes AI     | `ai_active`         | Return the owned inbox to the AI-ready state; do not send until a new eligible lead message exists |
| Any non-closed state               | Conversation resolved           | `closed`            | Cancel pending AI replies and automatic follow-ups                                                 |
| `closed`                           | Lead sends a new message        | `ai_active`         | Begin a new conversation lifecycle while retaining the existing Lead identity                      |

Assignment, human reply, pause, and resolution events are authoritative even when
an AI job was queued earlier. A queued job must not infer permission from the state
that existed when it was created.

## 6. Draft PostgreSQL Schema

All primary keys are UUIDs unless the table stores an external identifier. Every tenant-owned table includes `business_account_id`. Timestamps use UTC; business display and booking rules use the Business Account timezone.

### Tenancy and Access

#### `business_accounts`

- `id`, `name`, `timezone`, `status`.
- `meta_business_account_id` for the WhatsApp connection.
- Unique: `meta_business_account_id` when present.

#### `users`

- `id`, `email`, `name`, `status`, authentication metadata.
- A person may belong to multiple Business Accounts later.

#### `business_account_memberships`

- `business_account_id`, `user_id`, and `role`.
- Roles in v1: `admin`, `team_member`.
- Unique: `(business_account_id, user_id)`.

Authentication is owned by the application. V1 is invite-only and uses
email/password sign-in, verification, password recovery, and server-side
Business Account membership resolution. A browser never establishes tenant
scope by submitting an arbitrary `business_account_id`; the server verifies the
membership before any account selection or query.

#### `integration_connections`

- `business_account_id`, `provider`, `status`, external account identifiers, encrypted secret reference, scopes, expiry, and health metadata.
- Provider categories initially: `meta_whatsapp`, `ai_model`, and `calendar`; the concrete AI and calendar providers remain replaceable.
- Raw secrets must never be returned to the browser or written to logs.

#### `ai_orchestration_intents`

- `business_account_id`, conversation, triggering message, observed control
  version, state, idempotency key, selected provider, model, failure class,
  source references, review request, outbound message, attempts, and timestamps.
- Unique: `(business_account_id, idempotency_key)`.
- Workers lock the intent and Conversation before any lead-facing Outbound
  Message is created.

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

- `business_account_id`, `lead_id`, channel, external inbox ID, external conversation ID, Control State, Follow-up State, current question key, question debt, last activity timestamps, current Human Operator, and monotonic `control_version`.
- Unique: `(business_account_id, channel, external_conversation_id)`.

Every ownership-changing transition increments `control_version`. AI reply jobs
record the version they observed, but the worker must still lock and re-read the
Conversation before sending.

#### `messages`

- `business_account_id`, `conversation_id`, channel, external message ID, direction, actor type, text or media metadata, delivery state, occurred timestamp, and content hash.
- Actor types: `lead`, `ai_employee`, `human_operator`, `system`.
- Unique: `(business_account_id, channel, external_message_id)`.
- Message content follows the configured retention policy; secrets and unnecessary raw webhook data are excluded.
- A Channel Greeting is a visible template Outbound Message. An AI Employee
  answer is a separate visible Outbound Message and must not duplicate the
  greeting salutation.

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

- `business_account_id`, conversation ID, action type, run time, status, attempt count, observed control version, idempotency key, cancellation reason, and result metadata.
- Unique: `idempotency_key`.

#### `alert_routes`

- `business_account_id`, alert type, recipient membership or phone number, channel, priority threshold, and `enabled`.

#### `alerts`

- `business_account_id`, route ID, related entity type and ID, rendered summary, delivery state, external message ID, attempts, and timestamps.
- One logical alert uses one stable idempotency key even when delivery is retried.

#### Current owned-fork implementation

- Conflict-free call bookings are persisted as `bookings`, scoped by account,
  contact, Conversation, Lead Qualification, assignee, calendar, confirmation,
  calendar event, invitation, alert-delivery, and retry idempotency metadata.
- Active bookings cannot overlap for the same account calendar. The service
  checks availability transactionally, the model rejects overlaps, and
  PostgreSQL enforces the invariant with a GiST exclusion constraint.
- V1 stores booking configuration in account settings under
  `ai_lead_employee.booking` until calendar connections and availability rules
  are promoted to first-class records.
- The owned dashboard Bookings surface exposes configuration, available slots,
  confirmed booking state, and Human Operator preparation-alert visibility.
- Highly Qualified sales handoffs are persisted as `lead_handoffs`, scoped by
  account, contact, Conversation, qualification, assignee, alert type,
  qualification snapshot, alert recipients, and delivery attempts.
- `lead_handoffs` uses a unique logical-handoff key across Business Account,
  Conversation, Qualification, and alert type so replayed events do not create a
  second handoff or resend routed alerts.
- V1 stores sales handoff alert routes in account settings under
  `ai_lead_employee.alert_routes` until the admin alert-route UI promotes them
  to first-class records.

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
- Database changes and required side effects are committed together; workers deliver outbox events to Meta, calendar, and alert adapters.

## 7. Owned Inbox Attributes

The owned inbox stores these attributes directly:

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

Owned labels initially include `hot-lead`, `needs-review`, `follow-up-due`, and
`call-booked`. Inbox projections must be rebuilt through the outbox when needed.

## 8. Event Processing Invariants

1. Verify the Meta webhook signature before accepting an event.
2. Use the existing Community Edition WhatsApp webhook, event job, and channel
   service as the only production inbound Meta path.
3. Store and deduplicate the webhook before running AI logic.
4. Persist the Lead's Inbound Message and any configured Channel Greeting before
   AI Orchestration evaluates the Lead message.
5. Serialize processing per Conversation.
6. Immediately before sending an AI reply, lock and re-read Control State, inbox status, current owner, and `control_version` from PostgreSQL. Send only when the state is `ai_active`, the Conversation is still eligible, and the observed version still matches.
7. Persist the AI decision, Source References, outbound message intent, and outbox event in one database transaction.
8. Send through the existing WhatsApp sender using an idempotency key where supported and reconcile the external message ID.
9. A handoff request, human assignment, human reply, WhatsApp coexistence echo, manual pause, or resolution invalidates pending AI reply jobs. Human activity, pause, and resolution also invalidate automatic follow-up jobs.
10. Booking and alert creation are idempotent and retryable; Highly Qualified
    sales handoff alert idempotency is enforced by `lead_handoffs`.
11. Every Lead Quality transition records evidence, reasons, configuration version, and actor.
12. No cross-tenant query may execute without Business Account scope.
13. A duplicate Meta event has no second logical effect, even when it arrives after the first event has been processed.
14. Manual resume grants permission for future eligible work; it does not by itself send an AI reply.
15. Missing, conflicting, unverified, sensitive, angry, and provider-failed AI outcomes create safe Review Request behavior and no fabricated fallback.

## 9. Security and Operations

- Encrypt integration secrets at rest and rotate them without redeploying the application.
- Use least-privilege Meta, calendar, and AI-provider credentials.
- Redact message content and personal data from logs.
- Enforce role and Business Account scope at the API and query layers.
- Back up PostgreSQL and attachment storage, and test restoration.
- Track webhook delay, failed jobs, AI latency, answer refusals, handoffs, bookings, and alert delivery.
- Pin Chatwoot Community Edition and apply upstream security releases promptly.
- Define retention and deletion before onboarding an external client.

## 10. Implementation Order

1. Infrastructure and empty schema migrations.
2. Owned inbox baseline and access verification against the imported Community Edition source.
3. Canonical Community Edition WhatsApp webhook ingestion, deduplication, normalized messages, configured greeting, and outbound delivery.
4. Durable AI Orchestration boundary after message commit.
5. Secure provider-neutral AI adapter with OpenRouter initially.
6. Approved knowledge, Source References, provider failure classification, and Review Requests.
7. Control State, human takeover, WhatsApp coexistence echoes, and explicit resume.
8. Configurable offers, questions, rules, qualification evidence, handoff, alerts, booking, follow-up, dashboards, evaluations, launch gate, and controlled pilot.
