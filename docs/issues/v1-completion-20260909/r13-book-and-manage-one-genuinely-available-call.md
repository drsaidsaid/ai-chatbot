# R13 — Book and manage one genuinely available call

Status: Approved for implementation; blocked by the issues below.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/12

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Highly Qualified Lead can agree on a real available time and the assigned Human Operator can manage the Booking.

## What to build

Complete one calendar provider integration and the Booking agenda/detail path. Keep schedule viewing in Bookings and editable availability rules in Settings → Booking hours.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Use Google Calendar as the first V1 calendar provider, explicitly selected by the owner on 9 September 2026; record the provider decision before implementation.
- [ ] Connection and permission failures are distinct from an empty calendar; the operator has clear connect/retry guidance.
- [ ] Availability intersects actual free time with weekdays, hours, timezone, exceptions, buffers and minimum notice; display a useful preview of saved rules.
- [ ] Require a specific Lead-agreed time and recheck it before booking; simultaneous requests cannot reserve the same slot.
- [ ] A successful Booking creates the provider event and durable local record, updates Follow-up State and sends one eligible confirmation; optional email invitation uses only voluntarily supplied email.
- [ ] Reschedule/cancel and provider timeout/retry are idempotent and reconcile local/calendar state; do not show Confirmed for a stub or unknown result.
- [ ] Agenda and Calendar are views of the same Bookings, with readable phone details and a return-to-conversation path.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/21 (R04).
- https://github.com/drsaidsaid/ai-chatbot/issues/24 (R07).
- https://github.com/drsaidsaid/ai-chatbot/issues/26 (R09).
- https://github.com/drsaidsaid/ai-chatbot/issues/28 (R11).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
