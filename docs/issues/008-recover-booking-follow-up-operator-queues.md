# Recover Booking, Follow-Up, and Operator Queues

**Status:** Implemented

## What to build

Recover booking, follow-up, opt-out, and operator queue surfaces only after
qualification and handoff are canonical. These workflows must use durable
scheduled actions, existing WhatsApp delivery, explicit Control State checks,
and tenant-scoped operator views.

## Acceptance criteria

- [x] Only Highly Qualified Leads can receive automatic Booking offers.
- [x] Booking availability intersects connected calendar availability with
      Business Account working hours, buffers, and minimum notice.
- [x] Concurrent booking attempts cannot create overlapping active bookings.
- [x] Booking confirmations and preparation alerts are idempotent and sent
      through the existing WhatsApp path.
- [x] Incomplete qualification schedules follow-up based on the last unanswered
      useful question.
- [x] Human takeover, pause, resolution, booking, opt-out, and stale control
      version cancel incompatible scheduled actions.
- [x] Operator queues expose Leads, Hot Leads, Reviews, Bookings, follow-up,
      assignments, and Control State without cross-tenant leakage.
- [x] Tests cover booking conflicts, retry idempotency, follow-up cancellation,
      opt-out, role visibility, internal notes, and responsive dashboard workflows.

## Implementation notes

- Booking confirmation and preparation alert delivery now create durable
  account-owned `Message` records and enqueue the existing `SendReplyJob`
  WhatsApp sender path instead of sending directly from booking code.
- Booking availability remains constrained by connected calendar state,
  Business Account working hours, buffers, minimum notice, active bookings, and
  the database overlap exclusion constraint.
- Follow-up delivery cancels private/internal-note records, opt-outs, stale
  Control State versions, human takeover, pause, resolution, and booked/closed
  follow-up states.
- Operator queues now expose review status, follow-up status, assignment,
  booking state, and Control State filters in the existing Community Edition
  dashboard surface.

## Blocked by

- Ticket 007: Recover qualification, handoff, and alerting.
