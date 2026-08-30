# Canonical WhatsApp Round Trip with Channel Greeting

**Status:** Replacement blocker ticket

## What to build

Deliver the first corrected WhatsApp path through the existing owned Community
Edition WhatsApp webhook, event job, channel service, Conversation, Message,
configured Channel Greeting, and existing outbound sender. The duplicate custom
Meta webhook path must not be used for this slice.

## Acceptance criteria

- [ ] A verified Meta test-number message enters through
      `Webhooks::WhatsappController` and `Webhooks::WhatsappEventsJob`.
- [ ] The existing WhatsApp Cloud incoming service creates or updates the
      correct tenant-scoped Lead identity, Conversation, and visible Inbound
      Message.
- [ ] Replaying the same Meta event creates no duplicate message, greeting,
      delivery, or side effect.
- [ ] When a Channel Greeting is configured for a first Lead message, the Lead's
      message is persisted first and the greeting is recorded and sent once as
      visible conversation history.
- [ ] Unsupported media is visible to the Human Operator and does not trigger
      fabricated AI content.
- [ ] One controlled non-AI outbound Message uses the existing WhatsApp sender
      and stores Meta's message identifier.
- [ ] Meta delivery statuses reconcile onto the persisted Message.
- [ ] Tests cover signature verification, phone-number/channel lookup,
      duplicate events, greeting ordering, unsupported media, outbound delivery, and
      status reconciliation.

## Blocked by

- Ticket 000: Owned Community Edition baseline, access, and route audit.
