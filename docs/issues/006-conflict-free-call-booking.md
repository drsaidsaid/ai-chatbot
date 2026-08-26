# Conflict-Free Call Booking

## What to build

Let a Highly Qualified Lead choose from times permitted by both the connected
calendar and configurable business availability. Create the booking directly,
send WhatsApp confirmation, and include an email calendar invitation only when
the Lead voluntarily provides an email address.

## Acceptance criteria

- [x] An admin can connect a calendar and configure timezone, working days, allowed hours, duration, buffers, and minimum notice.
- [x] The AI offers only times allowed by both calendar availability and custom rules.
- [x] Two Leads cannot obtain the same active slot, including under concurrent requests.
- [x] A selected slot creates a durable Booking linked to the Lead, Conversation, qualification evidence, and assignee.
- [x] The Lead receives a WhatsApp confirmation with the local date and time.
- [x] A calendar invitation is sent only when the Lead has supplied an email address.
- [x] The Human Operator receives a preparation alert with summary, strongest evidence, likely objection, and suggested opening question.
- [x] Retries do not create duplicate calendar events, confirmations, or alerts.

## Blocked by

- Ticket 005: Highly Qualified handoff and WhatsApp alert.

## Implementation notes

- Added settings-backed booking configuration, available-slot lookup, and booking
  creation APIs under the owned account boundary.
- Added durable Booking storage with account, contact, Conversation,
  qualification, assignee, confirmation, invitation, alert, and idempotency
  metadata.
- Enforced active-slot protection with both model validation and a PostgreSQL
  exclusion constraint over overlapping active bookings for the same calendar.
- Added the owned dashboard Bookings panel for booking settings, available
  slots, confirmed bookings, confirmation state, and Human Operator prep-alert
  visibility.
- Booking creation marks the Lead follow-up state as call booked, advances the
  Conversation control version, creates the calendar event payload, sends the
  Lead WhatsApp confirmation, conditionally records an email invitation, and
  sends the Human Operator preparation alert.
