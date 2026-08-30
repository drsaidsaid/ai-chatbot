# Recover Booking, Follow-Up, and Operator Queues

**Status:** Recovery ticket

## What to build

Recover booking, follow-up, opt-out, and operator queue surfaces only after
qualification and handoff are canonical. These workflows must use durable
scheduled actions, existing WhatsApp delivery, explicit Control State checks,
and tenant-scoped operator views.

## Acceptance criteria

- [ ] Only Highly Qualified Leads can receive automatic Booking offers.
- [ ] Booking availability intersects connected calendar availability with
      Business Account working hours, buffers, and minimum notice.
- [ ] Concurrent booking attempts cannot create overlapping active bookings.
- [ ] Booking confirmations and preparation alerts are idempotent and sent
      through the existing WhatsApp path.
- [ ] Incomplete qualification schedules follow-up based on the last unanswered
      useful question.
- [ ] Human takeover, pause, resolution, booking, opt-out, and stale control
      version cancel incompatible scheduled actions.
- [ ] Operator queues expose Leads, Hot Leads, Reviews, Bookings, follow-up,
      assignments, and Control State without cross-tenant leakage.
- [ ] Tests cover booking conflicts, retry idempotency, follow-up cancellation,
      opt-out, role visibility, internal notes, and responsive dashboard workflows.

## Blocked by

- Ticket 007: Recover qualification, handoff, and alerting.
