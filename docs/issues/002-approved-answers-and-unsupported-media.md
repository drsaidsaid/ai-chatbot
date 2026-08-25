# Approved Answers and Unsupported Media

## What to build

Allow the AI Employee to answer a lead's business or offer question using only
approved knowledge. FAQ, offer, and pricing knowledge must outrank supporting
documents. When the system cannot safely answer, it must not invent an answer.
Voice notes are retained as message metadata and receive the configured request
for text instead of being transcribed in V1.

## Acceptance criteria

- [ ] An admin can add, edit, approve, reject, and deactivate knowledge used by the AI Employee.
- [ ] An approved FAQ answer can travel from a real WhatsApp question through the AI service and back through Meta.
- [ ] FAQ, offer, and pricing sources win when supporting documents conflict.
- [ ] Unapproved, rejected, and cross-tenant knowledge cannot appear in a lead-facing answer.
- [ ] Out-of-scope topics receive a brief boundary response and no extended conversation.
- [ ] A voice note is visible to the operator and the lead is asked to send the content as text.
- [ ] The operator view identifies the sources used or the reason the system refused to answer.
- [ ] Automated checks cover approved, conflicting, missing, and tenant-isolation cases.

## Blocked by

- Ticket 001: WhatsApp round trip and safe human takeover.
