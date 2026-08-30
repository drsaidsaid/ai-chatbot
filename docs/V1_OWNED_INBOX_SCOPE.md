# V1 Owned Inbox Surface

AI Lead Employee V1 is an operator workspace for handling and qualifying
WhatsApp leads. It retains Community Edition capabilities that support this
workflow and hides unrelated capabilities without deleting their source.

The UI and UX should remain recognizably Community Edition-derived: the same
dashboard shell, inbox layout, component vocabulary, Tailwind styling approach,
and interaction model should carry the owned AI Lead Employee surfaces. V1
navigation is narrowed and rebranded, but the product must not feel like a
separate application bolted beside Community Edition.

## Visible V1 areas

- **Inbox:** conversation list, messages, notes, assignment, labels, human
  takeover, pause, resume, and resolution.
- **Hot Leads:** highly qualified Leads needing immediate Human Operator action.
- **Leads:** searchable Lead list and lead detail, including phone number,
  qualification evidence, quality, reason, assignee, source, and booking state.
- **Reviews:** unanswered questions and decisions awaiting a Human Operator.
- **Knowledge:** approved FAQ, offer, pricing, objection, policy, and supporting
  Knowledge Items with explicit approval.
- **Bookings:** confirmed and upcoming Booking records with the assigned Human
  Operator.
- **Settings:** Business Account profile, team invitations, offers,
  qualification questions and rules, availability, alert routes, and direct
  Meta WhatsApp connection health.

V1 supports one direct WhatsApp connection per Business Account. Lead messages,
human replies, AI replies, and alert delivery use that connection.

The supported connection is the owned Community Edition WhatsApp channel path:
the existing webhook, event job, channel service, Conversation, Message, and
outbound sender. A parallel custom Meta webhook is outside the supported V1
surface until removed or folded into that path.

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
