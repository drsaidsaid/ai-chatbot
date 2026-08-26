# Approved Answers and Unsupported Media

## What to build

Allow the AI Employee to answer a lead's business or offer question using only
approved knowledge. FAQ, offer, and pricing knowledge must outrank supporting
documents. When the system cannot safely answer, it must not invent an answer.
Voice notes are retained as message metadata and receive the configured request
for text instead of being transcribed in V1.

## Acceptance criteria

- [x] An admin can add, edit, approve, reject, and deactivate knowledge used by the AI Employee.
- [x] An approved FAQ answer can travel from a real WhatsApp question through the AI service and back through Meta.
- [x] FAQ, offer, and pricing sources win when supporting documents conflict.
- [x] Unapproved, rejected, and cross-tenant knowledge cannot appear in a lead-facing answer.
- [x] Out-of-scope topics receive a brief boundary response and no extended conversation.
- [x] A voice note is visible to the operator and the lead is asked to send the content as text.
- [x] The operator view identifies the sources used or the reason the system refused to answer.
- [x] Automated checks cover approved, conflicting, missing, and tenant-isolation cases.

## Blocked by

- Ticket 001: WhatsApp round trip and safe human takeover.

## Implementation progress

- Added tenant-scoped Knowledge Items with source kind, lifecycle state, approval, rejection, and deactivation timestamps.
- Added admin API endpoints to create, edit, approve, reject, deactivate, list, and view Knowledge Items.
- Added a deterministic Knowledge Answer Service that only uses approved active knowledge from the same Business Account and ranks FAQ, offer, and pricing sources ahead of supporting documents.
- Connected inbound Meta WhatsApp text messages to the AI Employee answer service and sends the selected answer or a brief boundary response through the controlled Meta outbound sender.
- Retains WhatsApp voice notes as unsupported message metadata and replies with the V1 request for text instead of transcribing.
- Exposes the last AI Employee answer source or refusal reason in the conversation API and sidebar panel.
