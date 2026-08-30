# Control State, Takeover, Coexistence, and Explicit Resume

**Status:** Replacement blocker ticket

## What to build

Complete the safety behavior around who may reply in a Conversation. Human
Operator replies, assignment, pause, resolution, handoff, and WhatsApp Business
app coexistence echoes must stop the AI Employee. Explicit resume must allow
future eligible AI Orchestration without sending immediately.

## Acceptance criteria

- [ ] Control State transitions are available for AI Active, Handoff Requested,
      Human Active, AI Paused, and Closed.
- [ ] Human assignment and Human Operator reply move the Conversation to Human
      Active and invalidate pending AI Orchestration.
- [ ] WhatsApp coexistence echoes are visible Outbound Messages and are treated
      as human activity for Control State.
- [ ] Pause and resolution invalidate pending AI and incompatible follow-up
      work.
- [ ] Handoff Requested opens the Conversation for a Human Operator without
      allowing more automated replies.
- [ ] Explicit resume returns the Conversation to AI Active for the next
      eligible Lead message only.
- [ ] Control State, owner, recent event history, pause, resume, assignment, and
      reply controls are visible in the owned inbox.
- [ ] Tests cover late AI jobs, duplicate events after takeover, coexistence
      echoes, assignment, pause, resolution, explicit resume, and internal notes
      never sending to Leads.

## Blocked by

- Ticket 002: Durable AI Orchestration intent and outbound boundary.
- Ticket 004: Grounded answer and Review Request tracer bullet.
