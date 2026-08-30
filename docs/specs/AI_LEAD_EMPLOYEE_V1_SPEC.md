# AI Lead Employee V1 Implementation Spec

**Status:** Replacement planning foundation
**Date:** 2026-08-30
**Product boundary:** Owned Community Edition fork, direct Meta WhatsApp Cloud API through the existing WhatsApp channel, durable grounded AI Orchestration

## Purpose

This spec replaces the misleading ticket-completion plan with the corrected V1
foundation. The current code contains useful Community Edition behavior and
later experiments, but production work must first prove the canonical WhatsApp
round trip and durable AI boundary.

## Canonical Acceptance Seam

The highest-priority acceptance seam is:

```text
WhatsApp message
  -> existing owned Community Edition Meta webhook
  -> visible persisted Conversation and Inbound Message
  -> configured Channel Greeting, when enabled
  -> durable grounded AI Orchestration job
  -> persisted Outbound Message with verified Source References
  -> existing WhatsApp outbound sender
  -> Meta delivery status reconciliation
```

No later qualification, booking, follow-up, dashboard, or launch feature is
complete until this seam works against the owned Rails/Vue application.

## Required Decisions

- AI Lead Employee is an owned product built from Chatwoot Community Edition
  source. There is no Chatwoot Cloud account, Chatwoot API token, Chatwoot
  webhook secret, separate Chatwoot database, or external Chatwoot runtime.
- Useful Community Edition inbox capabilities are retained and rebranded rather
  than rebuilt.
- Authentication is application-owned while retaining the existing User,
  Account, AccountUser, Devise, invitation, and tenancy foundations.
- Meta WhatsApp events enter through the existing owned Community Edition
  WhatsApp webhook path. The duplicate custom `/webhooks/meta/whatsapp` path is
  not production.
- A configured Channel Greeting is intentional and visible. It must not prevent
  the Lead's first message from being stored, and it must not cause duplicate
  AI salutations.
- AI Orchestration runs asynchronously after message persistence commits. Late
  jobs must re-check Control State, Inbox Conversation Status, assignment,
  opt-out state, and observed control version.
- Human replies, WhatsApp coexistence echoes, assignment, pause, and resolution
  stop the AI Employee. Resume is explicit and does not send immediately.
- AI provider integration is provider-neutral and OpenAI-compatible. OpenRouter
  is the first provider, with encrypted server-side credentials, admin-only
  configuration, approved relevant Knowledge Items, verified Source References,
  failure classification, and no fabricated fallback.
- AI Provider Connections are Business Account-owned records, not plaintext
  `Account.settings`. Admin APIs may configure, rotate, disable, and health-check
  a connection, but browsers never receive raw credentials and team members
  cannot infer whether credentials exist.
- Provider-specific request routing, privacy options, and headers belong inside
  provider adapters. Domain services depend on the OpenAI-compatible boundary
  and classified failures, not on OpenRouter constants.
- The ticket-003 provider configuration slice may health-check the configured
  provider, but AI Orchestration must not send Lead content to a model provider
  until the grounded-answer slice verifies approved relevant sources.
- Review Request behavior is safe: the Lead receives only an approved boundary
  response or human-authored response, proposed knowledge stays unavailable
  until approved, and all work remains tenant-scoped.

## Code Reconciliation

The implementation must preserve and extend these owned Community Edition
surfaces:

- `Webhooks::WhatsappController`
- `Webhooks::WhatsappEventsJob`
- `Whatsapp::IncomingMessageWhatsappCloudService`
- `Conversation`
- `Message`
- `MessageTemplates::HookExecutionService`
- `MessageTemplates::Template::Greeting`
- `Whatsapp::SendOnWhatsappService`
- Existing Rails account membership, policy, invitation, and dashboard routing
  patterns

These current additions are donor/reference only until reconciled:

- `Webhooks::Meta::WhatsappController`
- `Meta::Whatsapp::InboundWebhookProcessor`
- `Meta::Whatsapp::OutboundMessageSender`
- `Meta::Whatsapp::TextMessageClient`
- Inline `AiLeadEmployee::WhatsappAutoReplyService` calls from webhook
  processing
- Deterministic knowledge, qualification, handoff, booking, follow-up, dashboard,
  and evaluation experiments built before the canonical seam was proven

## Invariants

- Every tenant-owned read and write resolves Business Account scope server-side.
- Meta webhook verification happens before persistence.
- Duplicate provider events have one logical effect.
- The Lead's Inbound Message is visible before any Channel Greeting or AI reply.
- Channel Greeting messages remain visible conversation history.
- AI Orchestration is created after commit and is idempotent by Business Account,
  Conversation, triggering Message, and observed control version.
- AI Orchestration locks and re-reads the Conversation before sending.
- The ticket-004 boundary records Lead-facing AI answer content only after
  approved relevant Knowledge Items produce verified fresh Source References and
  the final sending authority check still passes.
- Human Operator reply, assignment, pause, resolution, WhatsApp coexistence echo,
  opt-out, and stale control version all block automated sending.
- Explicit resume allows future eligible work only.
- Provider credentials never reach the browser or logs.
- Provider credentials are rejected unless Active Record encryption is
  configured; there is no plaintext fallback for AI Provider Connections.
- A missing or disabled AI Provider Connection is configuration state, not a
  reason to fabricate Lead-facing text.
- Lead-facing AI answers require approved Knowledge Items and verified Source
  References.
- Provider failures, missing knowledge, conflicting knowledge, unsupported media,
  sensitive questions, angry Leads, stale knowledge, and source verification
  failures do not fabricate answers.
- Internal notes are never sent to Leads.
- Delivery status reconciliation updates the persisted Message and does not
  trigger a second AI decision.

## Launch Proof

Before live AI operation is enabled, the team must demonstrate:

- Meta test number inbound event reaches the existing WhatsApp webhook.
- The correct Business Account, Lead identity, Conversation, and Inbound Message
  are visible in the owned inbox.
- A configured Channel Greeting is recorded and sent once.
- A durable AI Orchestration job answers the actual Lead message from approved
  knowledge with Source References.
- The existing WhatsApp sender delivers the Outbound Message and records Meta's
  message identifier.
- Delivery status webhooks reconcile sent, delivered, read, and failed states.
- Duplicate events, provider failures, stale jobs, human takeover, coexistence
  echoes, pause, resolution, explicit resume, and cross-tenant attempts are
  covered by automated tests.

## Recovery Rule

Later Q10-Q15-style features may be recovered only after the canonical round
trip, durable AI boundary, secure provider adapter, grounded Review Request
behavior, human takeover, and end-to-end proof are correct. Recovery must be
selective: reuse code that fits the domain model and discard code that depends
on the retired custom Meta path or inline AI decisions.
