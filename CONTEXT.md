# AI Lead Employee

AI Lead Employee receives business inquiries, determines whether each person is a suitable buyer, and coordinates the transition from automated conversation to human action.

## Current release scope

The standalone V1 completion programme uses the audited `74d156e3` runtime plus
integration bootstrap `5c3bbc2f`; exact provenance and schema authority are in
[ADR 0008](docs/adr/0008-canonical-v1-release-and-schema-provenance.md).
R01–R18 are the current acceptance tickets; historical Done notes are scoped
past evidence. The coordinator integrates ticket commits on
`codex/v1-completion-20260909`.

The main menu is Inbox, Leads, Bookings, Knowledge, Settings. Customer Review
Requests and Hot Leads are Inbox views; reusable content approvals belong in
Knowledge. Test Center lives in Settings → AI & testing. Basic business metrics
remain required within existing workspaces while generic CE Reports stays hidden.
V1 uses one direct Meta WhatsApp connection per Business Account, Google Calendar
as first calendar provider and the encrypted OpenRouter-compatible AI boundary.
Online Profits integration is separate. Business Account maps to CE `Account`
and tenant scope normally uses `account_id`; conceptual names do not imply new
tenancy tables. An Offer schema table alone does not prove Offer qualification.

## Language

R06 fixed-role authorization is specified by [ADR 0010](docs/adr/0010-assigned-conversation-access.md).
Admin (`administrator`) has Business Account-wide access. Team Member (`agent`)
access requires current membership and Conversation assignment. Lead identity
access does not grant access to every Conversation or combined Qualification.
Retained macro HTTP endpoints are unavailable in V1. Lead merges and bulk
deletion require Admin access; queued labels recheck current Lead visibility.

**Business Account**:
The tenant whose offers, knowledge, leads, conversations, rules, team, and integrations are isolated from every other business.
_Avoid_: Client account, workspace, company account

**Offer**:
A product, service, programme or other proposition a Business Account presents to Leads, with optional qualification and an explicit next step.
_Avoid_: Product, package, campaign

**Lead**:
A person or business identity that has contacted the Business Account and may be evaluated for an Offer.
_Avoid_: Customer, user, contact

**Conversation**:
A channel-specific exchange between a Lead and the Business Account. A Lead can have multiple conversations over time.
_Avoid_: Chat, thread, session

**Inbound Message**:
A message sent by a Lead to the Business Account through a configured channel.
_Avoid_: Webhook payload, event, user message

**WhatsApp Receipt**:
An internal durable copy of an authenticated Meta envelope and verified routing,
recorded before acknowledgement. Its channel-scoped logical events track
normalization, recovery and delivery history (ADR 0009); a receipt is not a
Conversation or proof that processing has completed.
Already queued legacy delivery updates share the same monotonic Message
projection as verified receipts.

**Outbound Message**:
A visible message sent by the Business Account to a Lead through the same channel conversation.
_Avoid_: Reply event, response payload

**Channel Greeting**:
A configured first response from the Business Account that welcomes a Lead at the start of a Conversation. It is visible conversation history, not hidden AI context.
_Avoid_: Bot intro, duplicate salutation, welcome hook

**WhatsApp Outbound Delivery**:
The durable ownership and outcome of dispatching one Outbound Message through
the existing WhatsApp sender. Pending, claimed and dispatching describe local
work; accepted requires a provider Message ID. Unknown requires reconciliation
or human review, never a blind resend. Provider sent/delivered/read facts remain
separate from acceptance. Booking change notices are Outbound Messages attributed
to the initiating Human Operator, with one notice per recorded mutation identity.
Delayed creation events preserve the saved outcome and reconcile the optimistic
reply with its persisted Message as one Inbox row.
See ADR 0011.

**Automated Contact Consent**:
The Lead's current permission for the AI Employee and automatic follow-ups to
send Lead-facing WhatsApp messages. V1 records explicit withdrawal and explicit
re-consent as immutable evidence for one automated-contact purpose. An active
withdrawal suppresses every Conversation for that Lead in the Business Account.
AI resume does not grant consent, and consent does not determine Qualification,
Conversation ownership, or Inbox Conversation Status.
_Avoid_: Follow-up status, AI control, marketing preference

**Consent Evidence**:
An immutable record of one explicit withdrawal or re-consent, linked to its
verified Inbound Message, Conversation, Lead, observed wording, event time,
recognizer version and recording actor. The active opt-out row is a current
projection of this history for dispatch checks; it is not the evidence history.
_Avoid_: Consent flag, resume event, inferred permission

**AI Employee**:
The automated participant that answers approved questions, gathers qualification evidence, and follows configured rules.
_Avoid_: Chatbot, agent, bot

**Human Operator**:
A person authorized to review, take ownership of, and reply to conversations.
_Avoid_: Agent, admin, salesperson

**Qualification**:
The current evaluation of a Lead for one Offer, including quality, score, reasons, evidence, and missing signals.
_Avoid_: Lead status, classification

**Qualification Evidence**:
A normalized fact supporting or contradicting a qualification signal, linked to the message or human edit that supplied it.
_Avoid_: Extracted field, AI guess

**Lead Quality**:
The qualification outcome: Unknown, Unqualified, Low Qualified, Qualified, or Highly Qualified.
_Avoid_: Status, stage, temperature

**Hot Lead**:
An operational description of a Highly Qualified Lead that requires immediate human attention. It is not a separate Lead Quality value.
_Avoid_: Hot quality, hot status

**Follow-up State**:
The next-action condition for a Lead: no follow-up, nurture, human review, call booked, or closed.
_Avoid_: Lead status, conversation status

**Control State**:
The authority governing who may reply automatically: AI Active, Handoff Requested, Human Active, AI Paused, or Closed.
_Avoid_: Conversation status, bot status

**AI Orchestration**:
The durable work of deciding whether and how the AI Employee may answer an Inbound Message, using current Control State and approved knowledge.
The ticket-004 boundary retrieves approved relevant Knowledge Items, verifies Source References, calls the provider-neutral AI Provider adapter, re-checks authority, and records outbound delivery only when every source and authority check succeeds.
_Avoid_: Inline reply, webhook response, model call

**AI Provider Connection**:
The platform-operated, server-side model connection used by AI Orchestration and grounded answer work. ADR 0016 supersedes customer credential/model controls; per-Business Account metering remains isolated. The deployed R10 account-owned connection is a migration baseline, not the new customer configuration contract. It stores encrypted credentials outside `Account.settings`, exposes only redacted status to admins, and keeps provider-specific request details inside adapters.
R10's [provider control contract](docs/v1-completion-plan/2026-09-09/r10-provider-controls-preparation.md)
separates configured credentials, observed readiness at the configured reply
budget, and permission to automate within an explicit daily request allowance.
The R10 branch implements these controls from baseline `324ee6df`; its ticket
records bounded fake-provider, UI, build and browser verification before acceptance.
_Avoid_: OpenRouter settings, browser API key, account settings secret

**Handoff**:
The controlled transfer of a Conversation from the AI Employee to a Human Operator.
_Avoid_: Escalation, assignment

**Knowledge Item**:
An approved, versioned answer or rule that the AI Employee may use when responding.
_Avoid_: Memory, training data

**Source Reference**:
A verified identifier for the approved Knowledge Item or document section used to support an AI Employee answer.
_Avoid_: Citation guess, source text, retrieval blob

**Review Request**:
A question or decision the AI Employee cannot safely complete and has submitted to a Human Operator.
_Avoid_: Ticket, escalation

**Evaluation Run**:
An admin-only simulation record that executes AI Orchestration decisions without deliverable WhatsApp side effects and preserves the exact answer, Source References, evidence, qualification, next action, configuration, Knowledge Item versions, provider model, prompt version, and reviewer decision.
_Avoid_: Fake conversation, test chat

**Launch Gate**:
The server-side approval record that keeps live AI operation disabled until required Evaluation Runs, reviewed qualification accuracy, zero serious issues, team roleplay, pilot reviews, and admin approval are complete.
_Avoid_: Frontend toggle, feature flag

**Booking**:
A calendar reservation with confirmed start and end times, created under the selected Offer’s eligibility, Lead agreement and any applicable payment requirements.
_Avoid_: Call request, appointment lead

**Alert**:
A routed notification about a hot lead, booking, urgent review, or knowledge decision.
Hot Lead and Review Request WhatsApp alerts reuse the existing Community Edition WhatsApp sender by creating account-owned alert Contact, ContactInbox, Conversation, and outgoing Message records, then queueing `SendReplyJob` so delivery flows through `Whatsapp::SendOnWhatsappService`. When an approved WhatsApp template is configured, the alert Message carries CE `template_params` populated with the Handoff context so delivery can use the template path outside an active WhatsApp session. These records are operator-notification plumbing, not Lead-facing Conversations, and must remain tenant-scoped, Control-State-gated, and idempotent by Handoff delivery record.
_Avoid_: Message, notification event

**Inbox View**:
A permitted Conversation queue: All conversations, Needs review or Hot leads. Search and optional filters narrow Conversation records; a missing Qualification never hides an inquiry.
_Avoid_: Lead-only inbox, dashboard qualification list

**Inbox Conversation Status**:
The owned inbox's operational state: pending, open, snoozed, or resolved. It must never be used as Lead Quality.
_Avoid_: Status


## Managed service terms (ADR 0016)

**Platform Operator**: An authorised operator of this software service, distinct from a Business Account admin. Manages provider configuration, service plans and verified subscription payments across explicitly authorised accounts.

**AI Reply Credit**: One customer allowance unit for a completed logical AI reply settled after confirmed canonical send. Bubble count, model call count and static template fan-out do not multiply it.

**Subscription**: A Business Account’s paid monthly plan, renewal date and included allowance. Separate purchased top-ups carry forward while active.

**Offer Price**: The authoritative published commercial amount/conditions/effective dates for an Offer, distinct from Lead budget and platform Subscription price.

**Payment Confirmation**: An authorised recorded verification of a specific payment and its purpose. Platform subscriptions and the Business Account’s own paid Offers have different authority and entitlements.
