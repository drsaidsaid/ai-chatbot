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

- [x] A real WhatsApp message received directly from Meta creates or updates the correct tenant-scoped Lead, Conversation, and Message records.
- [x] Replaying the same Meta event produces no duplicate message or side effect.
- [x] The system can send one controlled test reply through Meta and reconcile the external message identifier.
- [x] Human assignment, human reply, pause, handoff, and resolution cancel pending AI replies.
- [x] A deliberately delayed AI job is blocked after a Human Operator takes control.
- [x] Manual resume permits future eligible AI work but sends no immediate message.
- [x] The owned inbox shows message delivery status, Control State, owner, and event history.
- [x] Integration tests record the confirmed Meta webhook shapes and event-ordering assumptions.

## Blocked by

- Ticket 000: Owned Community Edition baseline and access.

## Implementation progress

- Added the owned `/webhooks/meta/whatsapp` callback endpoint for Meta verify-token challenge handling and signed raw-body POST validation.
- Persisted Meta WhatsApp webhook events before processing, with database-backed idempotency for inbound messages and delivery statuses.
- Normalized signed inbound text payloads into tenant-scoped Contact, ContactInbox, Conversation, and Message records.
- Reconciled Meta delivery statuses onto existing outbound Message records.
- Added Conversation Control State and Control Version fields, plus an outbound text sender that locks and rechecks them immediately before sending to Meta.
- Wired Human Operator assignment, public reply, pause, manual resume, bot handoff, and resolution into Control State/Control Version invalidation.
- Linked Meta webhook events to conversations and exposed recent event history in the conversation API response.
- Added an AI Employee sidebar panel in the existing inbox showing Control State, Control Version, pause/resume controls, and recent Meta event history.
