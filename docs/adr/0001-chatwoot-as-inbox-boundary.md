---
status: superseded by ADR-0002
---

# Superseded external Chatwoot inbox boundary

This ADR is retained as historical context only. ADR-0002 superseded this
external-service boundary when AI Lead Employee became an owned product built
from the Community Edition source.

AI Lead Employee will integrate with an upstream-compatible Chatwoot Community Edition deployment through webhooks, APIs, AgentBot handoff, custom attributes, and Dashboard Apps. Chatwoot owns channel delivery and inbox operations; our service owns tenant configuration, lead qualification and evidence, AI control state, knowledge, booking, alerts, audit, and evaluations. This avoids rebuilding a mature inbox while preventing Chatwoot's schema, licensing, or upgrade cycle from owning the product's differentiating logic.

## Consequences

- Chatwoot Community Edition remains pinned and minimally modified; unused open-source features are hidden through configuration instead of deleted.
- Our database is authoritative for owned concepts, while selected summaries are mirrored into Chatwoot for operators.
- Every Chatwoot webhook is deduplicated before any AI reply or side effect.
- Stable external identifiers and a channel adapter make it possible to upgrade or replace Chatwoot later.
- Chatwoot Enterprise code is excluded from production unless separately licensed.
