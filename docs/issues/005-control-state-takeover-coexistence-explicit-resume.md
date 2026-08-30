# Control State, Takeover, Coexistence, and Explicit Resume

**Status:** Implemented in `codex/005-control-state-takeover-coexistence-explicit-resume`

## What to build

Complete the safety behavior around who may reply in a Conversation. Human
Operator replies, assignment, pause, resolution, handoff, and WhatsApp Business
app coexistence echoes must stop the AI Employee. Explicit resume must allow
future eligible AI Orchestration without sending immediately.

## Acceptance criteria

- [x] Control State transitions are available for AI Active, Handoff Requested,
      Human Active, AI Paused, and Closed.
- [x] Human assignment and Human Operator reply move the Conversation to Human
      Active and invalidate pending AI Orchestration.
- [x] WhatsApp coexistence echoes are visible Outbound Messages and are treated
      as human activity for Control State.
- [x] Pause and resolution invalidate pending AI and incompatible follow-up
      work.
- [x] Handoff Requested opens the Conversation for a Human Operator without
      allowing more automated replies.
- [x] Explicit resume returns the Conversation to AI Active for the next
      eligible Lead message only.
- [x] Control State, owner, recent event history, pause, resume, assignment, and
      reply controls are visible in the owned inbox.
- [x] Tests cover late AI jobs, duplicate events after takeover, coexistence
      echoes, assignment, pause, resolution, explicit resume, and internal notes
      never sending to Leads.

## Verification

- Direct Rails regression: `POSTGRES_USERNAME=ghalyasaid bundle exec rspec`
  against the ticket-related AI orchestration, WhatsApp, conversation API,
  assignment, message, policy, and follow-up specs passed with 239 examples.
- Vue regression: `pnpm test` passed with 422 files and 4246 tests.
- Lint/build: focused RuboCop, focused ESLint, full ESLint error-only, Rails
  autoload, migration status, and production assets passed.
- Broad Rails suite was interrupted after it produced no new progress for several
  minutes; it printed 1881 examples, 23 failures, and 8 pending. The reported
  failures were outside this ticket path: agent invitation mail expectations,
  CSAT export, dashboard rendering, Devise OAuth rendering, installation
  onboarding, and public portal article/category rendering.

## Blocked by

- Ticket 002: Durable AI Orchestration intent and outbound boundary.
- Ticket 004: Grounded answer and Review Request tracer bullet.
