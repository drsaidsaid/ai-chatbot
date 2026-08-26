# Operational Dashboard and Team Access

## What to build

Complete the operator experience around the owned inbox. Admins need clear
queues for all Leads, Highly Qualified Leads, unanswered questions, follow-up,
and booked calls. Human Operators need the conversations and actions assigned to
them. AI Lead Employee is authoritative for inbox operations, qualification, and
control state.

## Acceptance criteria

- [x] The dashboard provides inbox, Leads, Highly Qualified, unanswered-question, knowledge-approval, booking, and basic-performance views.
- [x] Lead rows show name, phone number, contact details, quality, reasons, assignee, source, and booking state without opening every conversation.
- [x] Operators can filter and save queues by quality, Follow-up State, assignee, source, unanswered questions, and booking status.
- [x] An authorized user can reply, take over, pause, resume, assign, reassign, and add a private note.
- [x] Internal notes can never be sent to a Lead.
- [x] Admins see all tenant activity; Human Operators see only permitted or assigned records.
- [x] Every sensitive action is tenant-scoped and recorded in append-only audit history.
- [x] Inbox labels and attributes can be rebuilt from authoritative product data.
- [x] Desktop and mobile layouts support the primary operator workflows without overlapping controls or text.

## Blocked by

- Ticket 001: WhatsApp round trip and safe human takeover.
- Ticket 005: Highly Qualified handoff and WhatsApp alert.
