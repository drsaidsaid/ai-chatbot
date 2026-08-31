# Evaluation Sandbox and Controlled Pilot Gate

**Status:** Implemented

## What to build

Build the admin simulation and launch gate after the recovered V1 workflows run
through the canonical foundation. The sandbox must inspect AI Orchestration
decisions without sending real WhatsApp messages and must gate live AI operation
on reviewed results.

## Acceptance criteria

- [x] An admin can run simulated Conversations without sending WhatsApp messages.
- [x] Each step shows selected answer, Source References, extracted evidence,
      Lead Quality, score, next question, Review Request, handoff, booking, and
      follow-up decisions.
- [x] Reusable scenarios cover approved answers, unknown questions, sensitive
      questions, angry Leads, unsupported media, duplicate events, stale AI jobs,
      human takeover, coexistence echoes, opt-out, booking conflicts, and tenant
      isolation.
- [x] Reviewers grade answer correctness, qualification correctness, tone,
      safety, source quality, and next action.
- [x] Live AI operation cannot be enabled until required checks pass and an
      admin records approval.
- [x] The launch report confirms 85-90% reviewed qualification accuracy and zero
      serious fabricated, harmful, or policy-breaking answers.
- [x] Every evaluated decision records configuration version, Knowledge Item
      versions, provider model, prompt version, and reviewer decision.

## Blocked by

- Ticket 008: Recover booking, follow-up, and operator queues.

## Implementation notes

- The documented reviewed qualification threshold is 85%. A launch gate is not
  ready until all required scenarios have reviewed passing runs, reviewed
  qualification accuracy is at least 85%, serious issues are zero, team roleplay
  is recorded, at least three pilot conversations are reviewed, and an admin
  records approval.
- Simulation uses the AI Orchestration intent processor with delivery enqueueing
  disabled and wraps scenario data in a rollback transaction, then persists only
  the evaluation snapshot.
- Review Request alerts use the canonical Community Edition Message,
  `SendReplyJob`, and WhatsApp channel sender path. Custom production
  `Meta::Whatsapp::TextMessageClient` alert delivery is not part of the
  supported architecture.
