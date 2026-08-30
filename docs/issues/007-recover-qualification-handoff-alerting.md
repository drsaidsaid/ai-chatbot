# Recover Qualification, Handoff, and Alerting

**Status:** Implemented on `codex/007-recover-qualification-handoff-alerting`

## What to build

After the canonical launch proof passes, selectively recover qualification,
Highly Qualified handoff, and WhatsApp alert behavior from donor code. The
recovered path must run through durable AI Orchestration and the existing
WhatsApp sender.

## Acceptance criteria

- [x] Qualification evidence is extracted from persisted Lead messages and
      linked to Source References or human edits.
- [x] The AI Employee asks one qualification question at a time and does not
      repeat known facts.
- [x] Lead Quality remains separate from Follow-up State, Control State, and
      Inbox Conversation Status.
- [x] Highly Qualified requires current evidence for pain, urgency, budget, and
      decision authority.
- [x] An unqualified Lead requesting a human does not trigger a sales handoff.
- [x] A Highly Qualified Lead creates one idempotent handoff and the configured
      WhatsApp alert with full context.
- [x] Assignment and alert delivery respect Control State, tenant isolation, and
      duplicate-event idempotency.
- [x] Tests cover returning Leads, human evidence correction, unsupported human
      requests, highly qualified handoff, alert retries, and cross-tenant rejection.

## Implementation notes

- Qualification runs inside durable AI Orchestration and extracts normalized
  evidence from persisted incoming Lead messages for the account/contact.
- Evidence snapshots include source references to message-backed evidence or
  human edits; the dashboard correction action records a human edit and audit.
- Hot Lead handoff alerts reuse the CE WhatsApp sender by creating marked,
  account-owned alert conversations/messages for configured recipients. If the
  account configures an approved WhatsApp template for the alert type, those
  messages include CE `template_params` populated with full Handoff context.
  Delivery jobs are queued after the orchestration transaction commits.
- Existing handoffs only retry failed alert delivery while the Conversation is
  open and Human Active; closed, paused, or AI-active conversations do not
  re-alert.

## Blocked by

- Ticket 006: End-to-end canonical launch proof.
