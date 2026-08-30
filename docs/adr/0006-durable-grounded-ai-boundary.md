---
status: accepted
---

# Run grounded AI work after message persistence through a durable boundary

AI Lead Employee will not make lead-facing AI decisions inline inside webhook processing. After an Inbound Message commits, the application records a durable AI Orchestration intent and a worker re-checks tenant scope, Control State, Inbox Conversation Status, assignment, opt-out, source references, and the observed control version before creating any Outbound Message.

The first durable-boundary slice may record a private outbound intent and
source-reference placeholder only. A lead-facing AI answer requires a later
grounded decision with verified Source References.

## Consequences

- A stale AI job, duplicate Meta event, human reply, WhatsApp coexistence echo, assignment, pause, or resolution must prevent automated sending.
- Model integration is provider-neutral and OpenAI-compatible, with OpenRouter as the initial configured provider rather than a hard-coded product dependency.
- Provider credentials are encrypted server-side, configurable only by admins, never returned to browsers, and never logged.
- The AI Employee may answer only from approved relevant Knowledge Items with verified Source References. Unknown, conflicting, sensitive, angry, provider-failed, or source-unverified outcomes create safe Review Request behavior and no fabricated fallback.
