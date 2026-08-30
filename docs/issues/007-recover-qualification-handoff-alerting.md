# Recover Qualification, Handoff, and Alerting

**Status:** Recovery ticket

## What to build

After the canonical launch proof passes, selectively recover qualification,
Highly Qualified handoff, and WhatsApp alert behavior from donor code. The
recovered path must run through durable AI Orchestration and the existing
WhatsApp sender.

## Acceptance criteria

- [ ] Qualification evidence is extracted from persisted Lead messages and
      linked to Source References or human edits.
- [ ] The AI Employee asks one qualification question at a time and does not
      repeat known facts.
- [ ] Lead Quality remains separate from Follow-up State, Control State, and
      Inbox Conversation Status.
- [ ] Highly Qualified requires current evidence for pain, urgency, budget, and
      decision authority.
- [ ] An unqualified Lead requesting a human does not trigger a sales handoff.
- [ ] A Highly Qualified Lead creates one idempotent handoff and the configured
      WhatsApp alert with full context.
- [ ] Assignment and alert delivery respect Control State, tenant isolation, and
      duplicate-event idempotency.
- [ ] Tests cover returning Leads, human evidence correction, unsupported human
      requests, highly qualified handoff, alert retries, and cross-tenant rejection.

## Blocked by

- Ticket 006: End-to-end canonical launch proof.
