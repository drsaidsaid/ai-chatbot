# Canonical WhatsApp Round Trip with Channel Greeting

**Status:** Done

## What to build

Deliver the first corrected WhatsApp path through the existing owned Community
Edition WhatsApp webhook, event job, channel service, Conversation, Message,
configured Channel Greeting, and existing outbound sender. The duplicate custom
Meta webhook path must not be used for this slice.

## Ticket 000 retirement/quarantine plan

1. Keep `GET /webhooks/meta/whatsapp` and `POST /webhooks/meta/whatsapp`
   quarantined as `410 Gone` endpoints until all external Meta app callback URLs
   are confirmed to use `/webhooks/whatsapp/:phone_number`.
2. Build ticket 001 only against `Webhooks::WhatsappController`,
   `Webhooks::WhatsappEventsJob`, `Whatsapp::IncomingMessageWhatsappCloudService`,
   `MessageTemplates::HookExecutionService`, `MessageTemplates::Template::Greeting`,
   `Conversation`, `Message`, and `Whatsapp::SendOnWhatsappService`.
3. Do not call `Meta::Whatsapp::InboundWebhookProcessor`,
   `Meta::Whatsapp::OutboundMessageSender`, `Meta::Whatsapp::TextMessageClient`,
   or `AiLeadEmployee::WhatsappAutoReplyService` from the canonical round-trip.
4. Fold any reusable parsing, idempotency, unsupported-media, delivery-status,
   or test-fixture ideas from the custom Meta classes into the existing
   Community Edition WhatsApp services with new tests, then delete or leave the
   custom classes unused as donor code.
5. Ticket 001 is complete only when a spec fails if `/webhooks/meta/whatsapp`
   is used for canonical ingestion and when duplicate events, greeting ordering,
   unsupported media visibility, outbound delivery, and delivery-status
   reconciliation all pass through `/webhooks/whatsapp/:phone_number`.

## Acceptance criteria

- [x] A verified Meta test-number message enters through
      `Webhooks::WhatsappController` and `Webhooks::WhatsappEventsJob`.
- [x] The existing WhatsApp Cloud incoming service creates or updates the
      correct tenant-scoped Lead identity, Conversation, and visible Inbound
      Message.
- [x] Replaying the same Meta event creates no duplicate message, greeting,
      delivery, or side effect.
- [x] When a Channel Greeting is configured for a first Lead message, the Lead's
      message is persisted first and the greeting is recorded and sent once as
      visible conversation history.
- [x] Unsupported media is visible to the Human Operator and does not trigger
      fabricated AI content.
- [x] One controlled non-AI outbound Message uses the existing WhatsApp sender
      and stores Meta's message identifier.
- [x] Meta delivery statuses reconcile onto the persisted Message.
- [x] Tests cover signature verification, phone-number/channel lookup,
      duplicate events, greeting ordering, unsupported media, outbound delivery, and
      status reconciliation.

## Blocked by

- Ticket 000: Owned Community Edition baseline, access, and route audit.
