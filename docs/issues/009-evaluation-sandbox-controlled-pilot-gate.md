# Evaluation Sandbox and Controlled Pilot Gate

**Status:** Recovery ticket

## What to build

Build the admin simulation and launch gate after the recovered V1 workflows run
through the canonical foundation. The sandbox must inspect AI Orchestration
decisions without sending real WhatsApp messages and must gate live AI operation
on reviewed results.

## Acceptance criteria

- [ ] An admin can run simulated Conversations without sending WhatsApp messages.
- [ ] Each step shows selected answer, Source References, extracted evidence,
      Lead Quality, score, next question, Review Request, handoff, booking, and
      follow-up decisions.
- [ ] Reusable scenarios cover approved answers, unknown questions, sensitive
      questions, angry Leads, unsupported media, duplicate events, stale AI jobs,
      human takeover, coexistence echoes, opt-out, booking conflicts, and tenant
      isolation.
- [ ] Reviewers grade answer correctness, qualification correctness, tone,
      safety, source quality, and next action.
- [ ] Live AI operation cannot be enabled until required checks pass and an
      admin records approval.
- [ ] The launch report confirms 85-90% reviewed qualification accuracy and zero
      serious fabricated, harmful, or policy-breaking answers.
- [ ] Every evaluated decision records configuration version, Knowledge Item
      versions, provider model, prompt version, and reviewer decision.

## Blocked by

- Ticket 008: Recover booking, follow-up, and operator queues.
