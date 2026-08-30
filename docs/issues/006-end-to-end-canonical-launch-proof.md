# End-to-End Canonical Launch Proof

**Status:** Replacement blocker ticket

## What to build

Prove the corrected V1 foundation with one automated launch proof that exercises
the canonical seam from a real or Meta-test WhatsApp message to a visible
Conversation, Channel Greeting, grounded durable AI Employee answer, outbound
WhatsApp delivery, and delivery-status reconciliation.

## Acceptance criteria

- [ ] The launch proof uses the existing owned Community Edition WhatsApp
      webhook path and fails if the duplicate custom Meta webhook is used.
- [ ] It verifies Business Account scope, Lead identity, Conversation,
      Inbound Message, Channel Greeting, AI Orchestration intent, Source References,
      Outbound Message, Meta message identifier, and delivery status.
- [ ] It covers duplicate inbound events with no second logical effect.
- [ ] It covers stale AI jobs after human takeover, assignment, pause,
      resolution, WhatsApp coexistence echo, and explicit resume.
- [ ] It covers provider authentication failure, timeout, rate limit, invalid
      response, and source-unverified answer with no fabricated fallback.
- [ ] It proves a team member cannot access another Business Account's Leads,
      Conversations, Knowledge Items, Review Requests, provider configuration, or
      orchestration records.
- [ ] The launch report records tested code version, configuration version,
      Knowledge Item versions, provider model, test number, and remaining blockers.

## Blocked by

- Ticket 001: Canonical WhatsApp round trip with Channel Greeting.
- Ticket 002: Durable AI Orchestration intent and outbound boundary.
- Ticket 003: Secure OpenAI-compatible provider configuration.
- Ticket 004: Grounded answer and Review Request tracer bullet.
- Ticket 005: Control State, takeover, coexistence, and explicit resume.
