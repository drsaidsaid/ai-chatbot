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
| 000 | Owned Community Edition baseline, access, and route audit | None       | Ready         |
| 001 | Canonical WhatsApp round trip with Channel Greeting       | 000        | Blocked       |
| 002 | Durable AI Orchestration intent and outbound boundary     | 001        | Blocked       |
| 003 | Secure OpenAI-compatible provider configuration           | 002        | Implemented   |
| 004 | Grounded answer and Review Request tracer bullet          | 003        | Implemented   |
| 005 | Control State, takeover, coexistence, and explicit resume | 002, 004   | Blocked       |
| 006 | End-to-end canonical launch proof                         | 001-005    | Blocked       |
| 007 | Recover qualification, handoff, and alerting              | 006        | Blocked       |
| 008 | Recover booking, follow-up, and operator queues           | 007        | Blocked       |
| 009 | Evaluation sandbox and controlled pilot gate              | 008        | Implemented   |

The current frontier is tickets 000-006. Tickets 007-009 intentionally wait
until the route, greeting, durable AI boundary, secure provider adapter, grounded
review behavior, takeover, and launch proof are correct.
