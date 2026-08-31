# AI Lead Employee

AI Lead Employee receives business inquiries, determines whether each person is a suitable buyer, and coordinates the transition from automated conversation to human action.

## Language

**Business Account**:
The tenant whose offers, knowledge, leads, conversations, rules, team, and integrations are isolated from every other business.
_Avoid_: Client account, workspace, company account

**Offer**:
A service that a Business Account presents to leads and qualifies them for.
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

**Outbound Message**:
A visible message sent by the Business Account to a Lead through the same channel conversation.
_Avoid_: Reply event, response payload

**Channel Greeting**:
A configured first response from the Business Account that welcomes a Lead at the start of a Conversation. It is visible conversation history, not hidden AI context.
_Avoid_: Bot intro, duplicate salutation, welcome hook

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
The Business Account-owned, server-side OpenAI-compatible model connection used by AI Orchestration and grounded answer work. It stores encrypted credentials outside `Account.settings`, exposes only redacted status to admins, and keeps provider-specific request details inside adapters.
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
A calendar reservation created for a Highly Qualified Lead with confirmed start and end times.
_Avoid_: Call request, appointment lead

**Alert**:
A routed notification about a hot lead, booking, urgent review, or knowledge decision.
Hot Lead and Review Request WhatsApp alerts reuse the existing Community Edition WhatsApp sender by creating account-owned alert Contact, ContactInbox, Conversation, and outgoing Message records, then queueing `SendReplyJob` so delivery flows through `Whatsapp::SendOnWhatsappService`. When an approved WhatsApp template is configured, the alert Message carries CE `template_params` populated with the Handoff context so delivery can use the template path outside an active WhatsApp session. These records are operator-notification plumbing, not Lead-facing Conversations, and must remain tenant-scoped, Control-State-gated, and idempotent by Handoff delivery record.
_Avoid_: Message, notification event

**Inbox Conversation Status**:
The owned inbox's operational state: pending, open, snoozed, or resolved. It must never be used as Lead Quality.
_Avoid_: Status
