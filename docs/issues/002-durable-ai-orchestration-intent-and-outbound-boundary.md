# Durable AI Orchestration Intent and Outbound Boundary

**Status:** Replacement blocker ticket

## What to build

Create the durable AI Orchestration boundary after a Lead's Inbound Message
commits. The webhook path must only persist channel facts and enqueue or record
the orchestration intent. A worker must lock and re-check the Conversation
immediately before creating any AI Employee Outbound Message.

## Acceptance criteria

- [ ] A committed eligible Inbound Message creates one tenant-scoped AI
      Orchestration intent keyed by Business Account, Conversation, triggering
      Message, and observed control version.
- [ ] AI Orchestration starts only after message persistence and any Channel
      Greeting commit.
- [ ] The worker locks the intent and Conversation before creating an Outbound
      Message.
- [ ] The final send check reads current Control State, Inbox Conversation
      Status, assignee, opt-out state, and control version.
- [ ] Stale observed control version, assignment, human reply, pause,
      resolution, closed state, opt-out, or ineligible inbox status blocks sending.
- [ ] Manual resume permits future eligible orchestration only and does not send
      immediately.
- [ ] AI decision, Source References placeholder, outbound intent, and outbox
      event commit atomically before external delivery.
- [ ] Tests prove a delayed worker cannot send after takeover and a retried
      intent cannot create a second Outbound Message.

## Blocked by

- Ticket 001: Canonical WhatsApp round trip with Channel Greeting.
