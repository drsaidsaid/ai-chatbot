---
status: accepted
supersedes: 0001-chatwoot-as-inbox-boundary
---

# Build an owned AI Lead Employee inbox from the Community Edition source

AI Lead Employee will use the open-source Chatwoot Community Edition source as
the starting codebase for an owned product, not as an external service boundary.
The deployed application, frontend, Rails backend, PostgreSQL database, Redis,
authentication, API, background jobs, agent logic, and branding belong to us.

There is no Chatwoot account, Chatwoot API token, Chatwoot webhook secret, or
separate Chatwoot database in the target architecture. Inbound WhatsApp events
from Meta enter our deployed backend directly; outbound WhatsApp messages leave
from our backend directly through the Meta WhatsApp Cloud API.

The Community Edition content in the pinned source is MIT licensed. The license
notice must remain in all substantial copies. The upstream `enterprise/`
directory is excluded unless separately licensed.

## Enterprise boundary

We will not copy, run, modify, or distribute code from the upstream
`enterprise/` directory. Its license requires a separate Enterprise license for
production use. It is not a dependency of AI Lead Employee V1.

Some Enterprise product ideas are relevant, but they will be implemented in
our owned code only when the product needs them:

- Direct Meta WhatsApp Cloud API support is required in V1 and will be built
  from Meta's official API documentation.
- AI knowledge, reply assistance, qualification, and human handoff are core
  V1 product capabilities and will be built as owned modules.
- Audit history is useful in V1; custom roles, SLA policies, capacity rules,
  voice transcription, campaigns, customer portals, and billing are deferred.

## Consequences

- Our application owns the inbox UI and backend instead of integrating through
  AgentBot webhooks and Chatwoot APIs.
- AI control state, qualification, knowledge, alerts, booking, inbox messages,
  users, and audit history share our application boundary and database.
- Human users sign in through our authentication system and never need a
  Chatwoot account.
- Upstream Community Edition commits can be selectively merged after review;
  product-specific work lives in our own modules and migrations.
- We still need Meta WhatsApp Business Platform credentials. Those connect us to
  WhatsApp itself, not to Chatwoot or any Chatwoot-hosted service.
