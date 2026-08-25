# Conflict-Free Call Booking

## What to build

Let a Highly Qualified Lead choose from times permitted by both the connected
calendar and configurable business availability. Create the booking directly,
send WhatsApp confirmation, and include an email calendar invitation only when
the Lead voluntarily provides an email address.

## Acceptance criteria

- [ ] An admin can connect a calendar and configure timezone, working days, allowed hours, duration, buffers, and minimum notice.
- [ ] The AI offers only times allowed by both calendar availability and custom rules.
- [ ] Two Leads cannot obtain the same active slot, including under concurrent requests.
- [ ] A selected slot creates a durable Booking linked to the Lead, Conversation, qualification evidence, and assignee.
- [ ] The Lead receives a WhatsApp confirmation with the local date and time.
- [ ] A calendar invitation is sent only when the Lead has supplied an email address.
- [ ] The Human Operator receives a preparation alert with summary, strongest evidence, likely objection, and suggested opening question.
- [ ] Retries do not create duplicate calendar events, confirmations, or alerts.

## Blocked by

- Ticket 005: Highly Qualified handoff and WhatsApp alert.
