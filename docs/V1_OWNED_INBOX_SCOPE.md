# V1 Owned Inbox Surface

AI Lead Employee V1 is an operator workspace for handling and qualifying
WhatsApp leads. It retains Community Edition capabilities that support this
workflow and hides unrelated capabilities without deleting their source.

The UI and UX should remain recognizably Community Edition-derived: the same
dashboard shell, inbox layout, component vocabulary, Tailwind styling approach,
and interaction model should carry the owned AI Lead Employee surfaces. V1
navigation is narrowed and rebranded, but the product must not feel like a
separate application bolted beside Community Edition.

## Five primary V1 areas

- **Inbox:** Conversation list, replies, private notes, assignment, labels,
  takeover, pause, resume and resolution; All, Needs review and Hot leads views.
- **Leads:** searchable directory, Lead detail, qualification evidence, assignee,
  source, next action, permitted import/export and compact basic business metrics.
- **Bookings:** authoritative reservation agenda/calendar, details, reschedule and
  cancel; a shortcut opens Settings → Booking hours.
- **Knowledge:** Documents, Answers and Drafts & approvals for reusable content.
  Customer Review Requests resolve in Inbox, with links to related knowledge.
- **Settings:** Business & offers, Team & alerts, Booking hours, Follow-ups,
  WhatsApp connection and AI & testing. Full Test Center is admin-only here.

Phones keep Inbox, Leads, Bookings and More, with Knowledge and Settings inside
More. Existing supported deep links must redirect into the correct canonical
record. R02 implements the approved navigation; this document is a requirement,
not a claim that the inherited UI has already changed. See
[the approved specification](v1-completion-plan/2026-09-09/navigation.md).

V1 supports one direct WhatsApp connection per Business Account. Lead messages,
human replies, AI replies, and alert delivery use that connection.

The supported connection is the owned Community Edition WhatsApp channel path:
the existing webhook, event job, channel service, Conversation, Message, and
outbound sender. A parallel custom Meta webhook is outside the supported V1
surface until removed or folded into that path.

Review Request and Hot Lead alerts also use the same Community Edition
Conversation, Message, `SendReplyJob`, and WhatsApp sender path. Custom direct
Meta text senders are outside the supported production architecture.

Configured Channel Greetings are visible V1 conversation messages. They are
allowed to welcome a Lead once, but AI Employee replies must answer the actual
Lead message and avoid a second greeting.

## Retained but hidden

The owned fork retains underlying Community Edition code that may become useful
later, but removes it from navigation, permissions, and supported workflows for
V1. This includes generic contact administration, inbox types other than direct
WhatsApp, canned replies and macros, generic automation rules, reports,
campaigns, help center, customer portal, public API surfaces, marketplace apps,
and broad integration catalogs.

Hidden means unavailable to ordinary V1 users, not deleted. A later feature
must have its own product decision and tests before a hidden surface is enabled.

## Explicitly deferred

- Facebook Messenger, Instagram Direct, TikTok, and YouTube.
- Bulk outbound marketing campaigns.
- Customer-facing help center or portal.
- Social login, SAML, custom roles, impersonation, and complex team capacity
  management.
- Voice transcription and calling.
- Multi-calendar routing, CRM sync, and self-service client onboarding.
- Billing, subscriptions, and usage metering.

## Standalone provider and analytics decisions

Google Calendar is the approved first provider (R13). Basic operational metrics
are required in Leads and relevant workspaces (R16); hiding generic Reports
does not defer them. OpenRouter remains the initial encrypted AI connection.
Online Profits identity, purchases, access and journey integration are separate.
See [ADR 0008](adr/0008-canonical-v1-release-and-schema-provenance.md) for release
and schema authority; local boot never approves unattended live delivery.
