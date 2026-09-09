# R13 — Book and manage one genuinely available call

Status: Draft for breakdown review; not published and not assigned.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/12

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Highly Qualified Lead can agree on a real available time and the assigned Human Operator can manage the Booking.

## What to build

Complete one calendar provider integration and the Booking agenda/detail path. Keep schedule viewing in Bookings and editable availability rules in Settings → Booking hours.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Record the first supported calendar provider before marking this implementation ready; do not infer a provider from a placeholder label.
- [ ] Connection and permission failures are distinct from an empty calendar; the operator has clear connect/retry guidance.
- [ ] Availability intersects actual free time with weekdays, hours, timezone, exceptions, buffers and minimum notice; display a useful preview of saved rules.
- [ ] Require a specific Lead-agreed time and recheck it before booking; simultaneous requests cannot reserve the same slot.
- [ ] A successful Booking creates the provider event and durable local record, updates Follow-up State and sends one eligible confirmation; optional email invitation uses only voluntarily supplied email.
- [ ] Reschedule/cancel and provider timeout/retry are idempotent and reconcile local/calendar state; do not show Confirmed for a stub or unknown result.
- [ ] Agenda and Calendar are views of the same Bookings, with readable phone details and a return-to-conversation path.

## Blocked by

- R04 (replace with the published GitHub issue reference after approval).
- R07 (replace with the published GitHub issue reference after approval).
- R09 (replace with the published GitHub issue reference after approval).
- R11 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
