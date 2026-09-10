---
status: accepted
---

# Store AI provider credentials in a Business Account-owned encrypted connection

AI Lead Employee will store OpenAI-compatible model provider configuration in a
dedicated `ai_provider_connections` table scoped one-to-one to a Business
Account. Raw provider credentials are server-side only, encrypted with Rails
Active Record encryption, rejected when encryption is unavailable, and never
stored in plaintext `Account.settings`.

OpenRouter is the initial provider adapter. Domain services use the
provider-neutral AI Provider boundary and classified provider failures. Adapter
code owns OpenRouter-specific URL, headers, routing, and privacy-safe request
options such as denying provider data collection. Admin APIs may configure,
rotate, disable, and health-check the connection, but response payloads expose
only redacted connection status.

Ticket 003 does not make the ticket-002 placeholder orchestration path call a
model provider with Lead content. Grounded answer work may use the configured
provider only after approved relevant Knowledge Items and verified Source
References are available.

## Consequences

- Team members cannot view, create, update, health-check, or infer provider
  credential presence.
- Missing, disabled, failed, or refused provider calls become classified safe
  orchestration outcomes or health statuses; they never create fabricated
  Lead-facing fallback text.
- Future OpenAI-compatible providers can add adapters without changing
  orchestration domain services.
- Deployments must configure Rails Active Record encryption before enabling AI
  Provider Connections.

## R10 control extension

The encrypted provider ownership above remains accepted. R10's
[refreshed preparation](../v1-completion-plan/2026-09-09/r10-provider-controls-preparation.md)
adds explicit answer-budget readiness, an enforceable daily attempt allowance,
committed usage accounting and provider configuration revisions. A tiny probe
cannot establish capacity for a normal answer, and unavailable cost cannot be
reported as zero. The focused R10 branch implements this extension from reviewed
baseline `324ee6df`.

Follow-up review requires durable admission to use a separate bounded database
pool whenever provider work runs inside an application transaction. Checkout
failure blocks provider HTTP, while bookkeeping failure after HTTP suppresses
the output, leaves the reservation conservative, and terminates orchestration
recovery before another provider attempt. Provider-produced Messages
retain both the configuration revision and UTC allowance date used for admission;
the final WhatsApp boundary rejects either stale value. Health writes also reject
observations older than the latest persisted provider result. Evaluation evidence
cannot certify launch when no current provider connection exists.

Provider permission extends the existing ADR 0011 model/output/dispatch boundary;
it does not introduce another sender or hold Conversation locks during provider
HTTP. Explicit disablement or exhausted local allowance blocks pending automation.
R11 owns the common truthful provider-failure acknowledgment while permission
remains valid; no acknowledgment can bypass an administrative stop. R17 owns the
broader launch-evidence fingerprint and consumes R10's provider revision.

ADR 0012 is reserved by the coordinator for other work, so this implementation
extends the existing decision without allocating another ADR number. Verification
uses local fake-provider responses and does not authorize live provider calls.
