# V1 Implementation Tickets

These tickets are ordered as tracer-bullet slices. Each ticket must deliver a
narrow, demonstrable path through storage, services, Meta, the owned inbox, the operator
interface, and automated verification where those layers are relevant.

| ID | Title | Blocked by | Initial state |
|---|---|---|---|
| 000 | Owned Community Edition baseline and access | None | Done |
| 001 | Direct Meta WhatsApp round trip and safe human takeover | 000 | Done |
| 002 | Approved answers and unsupported media | 001 | Done |
| 003 | One-question-at-a-time lead qualification | 002 | Done |
| 004 | Unanswered-question review and knowledge approval | 002 | Done |
| 005 | Highly Qualified handoff and WhatsApp alert | 003 | Done |
| 006 | Conflict-free call booking | 005 | Done |
| 007 | Incomplete-lead follow-up and opt-out | 003 | Done |
| 008 | Operational dashboard and team access | 001, 005 | Done |
| 009 | Evaluation sandbox and launch gate | 002-008 | Blocked |

Ticket 001 is intentionally the first production proof. It must confirm direct
Meta WhatsApp webhooks, event ordering, owned-inbox behavior, and outbound
message delivery before later orchestration work depends on those assumptions.

Before starting ticket 006, review tickets 000-005 together in the running app:
confirm the owned dashboard shell, Meta WhatsApp round trip, safe human takeover,
approved-knowledge answers, one-question qualification, unanswered-question
review flow, and Highly Qualified handoff/alert path still work as one coherent
operator workflow.
