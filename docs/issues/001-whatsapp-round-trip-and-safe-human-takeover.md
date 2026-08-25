# Direct Meta WhatsApp Round Trip and Safe Human Takeover

## What to build

Deliver the first real end-to-end path from a WhatsApp message received directly
from Meta to a durable Conversation in the owned AI Lead Employee inbox and back
to WhatsApp.
Provide a minimal operator view showing the Conversation and its Control State.
A Human Operator must be able to take over, pause, and manually resume the AI.

This slice must validate Meta webhook payloads and event ordering. The sender
must lock and re-read durable ownership immediately before sending, so a queued
AI reply cannot escape after human takeover.

## Acceptance criteria

- [ ] A real WhatsApp message received directly from Meta creates or updates the correct tenant-scoped Lead, Conversation, and Message records.
- [ ] Replaying the same Meta event produces no duplicate message or side effect.
- [ ] The system can send one controlled test reply through Meta and reconcile the external message identifier.
- [ ] Human assignment, human reply, pause, handoff, and resolution cancel pending AI replies.
- [ ] A deliberately delayed AI job is blocked after a Human Operator takes control.
- [ ] Manual resume permits future eligible AI work but sends no immediate message.
- [ ] The owned inbox shows message delivery status, Control State, owner, and event history.
- [ ] Integration tests record the confirmed Meta webhook shapes and event-ordering assumptions.

## Blocked by

- Ticket 000: Owned Community Edition baseline and access.
