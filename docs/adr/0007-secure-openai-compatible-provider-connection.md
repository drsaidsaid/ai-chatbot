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
