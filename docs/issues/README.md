# V1 Implementation Tickets

These tickets replace the prior misleading "done" sequence. They are ordered as
blocker-first tracer-bullet slices and must be worked from
`codex/reconcile-v1-baseline` or a branch created from it.

Each ticket should deliver a narrow, demonstrable path through the owned
Community Edition Rails/Vue application. Later experimental code may be used as
donor material only after it is reconciled with the canonical WhatsApp path and
durable AI Orchestration boundary.

| ID  | Title                                                     | Blocked by | Initial state |
| --- | --------------------------------------------------------- | ---------- | ------------- |
| 000 | Owned Community Edition baseline, access, and route audit | None       | Done          |
| 001 | Canonical WhatsApp round trip with Channel Greeting       | 000        | Done          |
| 002 | Durable AI Orchestration intent and outbound boundary     | 001        | Done          |
| 003 | Secure OpenAI-compatible provider configuration           | 002        | Implemented   |
| 004 | Grounded answer and Review Request tracer bullet          | 003        | Implemented   |
| 005 | Control State, takeover, coexistence, and explicit resume | 002, 004   | Done          |
| 006 | End-to-end canonical launch proof                         | 001-005    | Done          |
| 007 | Recover qualification, handoff, and alerting              | 006        | Done          |
| 008 | Recover booking, follow-up, and operator queues           | 007        | Done          |
| 009 | Evaluation sandbox and controlled pilot gate              | 008        | Implemented   |
| 010 | Conversation Cockpit navigation and responsive shell      | 008        | Integrated    |
| 011 | Inbox Conversation Cockpit                                | 006-010    | Integrated    |
| 012 | Leads Directory and Detail                                | 008, 010   | In verification |
| 013 | Team Bookings Agenda, Calendar, and Availability          | 006, 010   | Planned       |
| 014 | Documents-First Knowledge Workspace                       | 004, 010   | Planned       |
| 015 | Test Center Simulation and Release Check                  | 009, 010   | Planned       |
| 016 | Settings Offers and Qualification                         | 003, 010   | Planned       |
| 017 | Settings Booking Hours and Team Assignment                | 006, 008, 010 | Planned     |
| 018 | Settings Follow-Ups, Alerts, and WhatsApp Connection      | 001, 005, 007, 010 | Planned |
| 019 | Final visual parity and end-to-end browser gate           | 011-018    | Planned       |

Tickets 000-009 form the secure runtime baseline. Tickets 010-019 are integrated
onto that baseline in order; UI donor branches must not replace the canonical
WhatsApp, durable orchestration, provider, or launch-gate implementation.
