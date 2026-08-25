# Open-Source Repository Research: AI Lead Employee

**Research date:** 2026-08-25  
**Product reference:** `PRODUCT_REQUIREMENTS.md`  
**Source policy:** Primary sources only: official repositories, licenses, project documentation, release/commit pages, and Meta's WhatsApp Business Platform documentation.

## Executive Recommendation

Use **Chatwoot Community Edition as an integrated shared-inbox and WhatsApp channel layer**, while building the AI Lead Employee's qualification, knowledge approval, scheduling, alerts, and product-specific lead model as a focused service owned by us.

Do **not** begin with a deep Chatwoot fork. Its webhook and API surfaces are sufficient for an initial integration, and keeping it close to upstream makes security updates materially easier. Store canonical qualification state in our database, optionally mirror summary fields into Chatwoot custom attributes, and put a narrow adapter between our service and Chatwoot so the inbox can be replaced later.

The closest codebase to the requested product surface is **Senqo**, but it uses Baileys and QR-linked WhatsApp Web sessions rather than Meta's official Cloud API. That violates the PRD's explicit official-API requirement and introduces account restriction, session reliability, and protocol-change risk. Treat Senqo only as a source of product and workflow patterns.

**Kapso WhatsApp Cloud Inbox** is the best small official-API starter reviewed. It is useful for borrowing inbox UI and Cloud API message-handling patterns, or for a quick internal prototype. It is not a production shared-inbox foundation by itself: it has no mature team, assignment, lead, qualification, audit, or human-takeover model, and the default setup depends on Kapso's hosted API and credentials.

### Recommended architecture

1. **Meta WhatsApp Cloud API -> Chatwoot:** official WhatsApp transport, message history, shared inbox, contacts, agents, teams, assignments, and manual replies.
2. **Chatwoot webhooks -> AI Lead Employee service:** ingestion, idempotency, business/account isolation, AI responses, question debt, qualification rules and scoring, knowledge retrieval, follow-up state, and audit events.
3. **AI Lead Employee service -> Chatwoot API:** send replies, update mirrored custom attributes, assign conversations, and stop automation when a human takes over.
4. **AI Lead Employee service -> calendar and WhatsApp alerts:** availability-aware booking, hot-lead alerts, unanswered-question alerts, and configurable recipients.
5. **Our database remains authoritative:** contacts are linked to Chatwoot identifiers, but lead quality, reasons, extracted evidence, consent, booking state, knowledge approvals, and evaluation labels remain portable.

## Shortlist

| Rank | Candidate | Category | Official Cloud API | Shared inbox / takeover | Commercial-use license | Production role | Recommendation |
|---:|---|---|---|---|---|---|---|
| 1 | [Chatwoot](https://github.com/chatwoot/chatwoot) | Omnichannel inbox | **Yes, direct** | **Strong** | MIT for Community Edition; enterprise directory separately licensed | Production-capable | **Integrate; do not deeply fork initially** |
| 2 | [Kapso WhatsApp Cloud Inbox](https://github.com/gokapso/whatsapp-cloud-inbox) | Official-API inbox starter | **Yes, through Kapso's Meta-compatible endpoint by default** | Basic single inbox; team takeover model absent | MIT | Starter/reference, not complete platform | **Borrow patterns or prototype; avoid core dependency without vendor review** |
| 3 | [Frappe CRM + Frappe WhatsApp](https://github.com/frappe/crm) | Lead-centric CRM ecosystem | Yes through an add-on | Partial; CRM is strong, shared WhatsApp inbox is less mature | AGPL-3.0 CRM; add-ons use mixed licenses | Plausible CRM-first foundation | **Consider only if CRM depth outranks inbox maturity** |
| 4 | [Zammad](https://github.com/zammad/zammad) | Support/ticket inbox | **Yes, direct** | **Strong** | AGPL-3.0 | Production-capable, but support-ticket shaped | **Integrate only if ticket workflows are acceptable** |
| 5 | [Senqo](https://github.com/devennn/senqo) | WhatsApp AI/CRM platform | **No: Baileys/WhatsApp Web** | Strong product surface | MIT | Unsafe for this production requirement | **Borrow UX/domain patterns only** |
| 6 | [Dify](https://github.com/langgenius/dify) | AI workflow/knowledge platform | No first-party inbox/channel | Human-in-loop workflow, not a team inbox | Modified Apache; multi-tenant restrictions | Optional AI sidecar | **Borrow patterns; avoid as core product** |
| 7 | [Meta WhatsApp API Examples](https://github.com/fbsamples/whatsapp-api-examples) | Official code samples | **Yes, direct** | None | Meta sample license, limited to Facebook services/APIs | Samples only | **Borrow payload, webhook, and signature patterns** |
| 8 | [Evolution API](https://github.com/evolution-foundation/evolution-api) | WhatsApp integration gateway | Yes in Cloud API mode; also offers unofficial Baileys | Connector integrations, not a full lead inbox | Modified Apache with added conditions | Connector at most | **Do not adopt; direct Chatwoot Cloud API is simpler** |

## Evaluation Against the PRD

Legend: **Strong** = substantially present; **Partial** = useful primitives but meaningful custom work; **No** = absent or unsuitable.

| Candidate | Contacts / leads | AI qualification extensibility | Booking / alerts / assignment | Deployment | Principal risk |
|---|---|---|---|---|---|
| Chatwoot | Strong contacts; lead fields via custom attributes or sidecar | Strong APIs/webhooks; qualification is custom | Teams/assignment strong; booking and hot-lead logic custom | Medium-high: Rails, PostgreSQL, Redis, workers | Upgrade burden if deeply forked; recent advisories require prompt patching |
| Kapso Inbox | Basic phone/conversation identity; no real lead model | Easy TypeScript extension, but app is intentionally small | Templates supported; team assignment, booking, alerts absent | Low-medium: Next.js plus hosted Kapso account | Kapso API dependency; limited authorization/audit/team controls |
| Frappe CRM | Strong lead, deal, contact, custom-field model | Extensible Frappe apps and hooks | Assignment strong; calendar possible; WhatsApp inbox/handoff integration incomplete | High: Frappe stack, database, Redis/workers | AGPL and mixed add-on licenses; integration fragmentation |
| Zammad | Strong users/custom objects, ticket-centric | API/webhook customization possible | Groups/agents strong; lead scoring and booking custom | High: several services; search stack commonly used | AGPL obligations; ticket model may distort lead lifecycle |
| Senqo | Strong CRM-like model | Strong built-in AI/knowledge concepts | Takeover, team, campaigns and scheduling are close to PRD | Medium: Docker, PostgreSQL, S3, several services | Unofficial WhatsApp protocol and very young project |
| Dify | No customer/lead system | Strong workflows, tools, RAG and human review | External tools required | High: multi-service Docker stack | License restrictions and unnecessary platform complexity |
| Meta Examples | No | Only code-level extension points | No | Low for samples, but production controls must be built | Samples lack auth, tenancy, observability, inbox, retry/audit completeness |
| Evolution API | Basic integration records, not a lead model | Integrates with AI/workflow tools | Connectors exist; product workflows are custom | Medium: Node, PostgreSQL, Redis | Mixed official/unofficial modes, license additions, extra gateway layer |

## Candidate Findings

### 1. Chatwoot: best production foundation

**Fit.** Chatwoot already owns the difficult operational inbox surface: conversations, contacts, agents, teams, assignments, channel connections, manual replies, message state, and webhooks. Its [contact API](https://developers.chatwoot.com/api-reference/contacts-api/create-a-contact) supports custom attributes, and its [conversation API](https://developers.chatwoot.com/api-reference/conversations/create-new-conversation) exposes custom attributes, assignee, and team fields. [Webhook subscriptions](https://developers.chatwoot.com/api-reference/webhooks/add-a-webhook) cover message, contact, and conversation events. Those are sufficient primitives for an external qualification service and human-takeover state machine.

**Official WhatsApp support.** Chatwoot documents a direct [WhatsApp Cloud API setup](https://www.chatwoot.com/hc/user-guide/articles/1784258744-how-to-setup-a-whatsapp-channel-manual-flow), and the repository contains the [WhatsApp channel implementation](https://github.com/chatwoot/chatwoot/blob/develop/app/models/channel/whatsapp.rb). This satisfies the PRD's requirement to avoid WhatsApp-Web bridges.

**License.** Code outside the `enterprise/` directory is covered by the [MIT Community Edition license](https://github.com/chatwoot/chatwoot/blob/develop/LICENSE); enterprise code has a [separate proprietary license](https://github.com/chatwoot/chatwoot/blob/develop/enterprise/LICENSE). Commercial self-hosting and modification of the Community Edition are permitted, but enterprise-only features must not be copied or assumed available.

**Activity and security.** The project released [v4.17.0 on 2026-08-20](https://github.com/chatwoot/chatwoot/releases/tag/v4.17.0), including WhatsApp and security-related work. It is actively maintained, but its [security advisory history](https://github.com/chatwoot/chatwoot/security/advisories) makes disciplined upgrades mandatory.

**Gaps.** The PRD-specific qualification rubric, question sequencing, lead-quality explanation, FAQ approval workflow, calendar arbitration, WhatsApp hot-lead alerts, evaluation labels, and business-level analytics remain custom. This is appropriate: they are the differentiating product, not generic inbox behavior.

**Decision: integrate.** Run an upstream-compatible Community Edition deployment and connect through supported APIs/webhooks. Reconsider a narrow fork only after a proof identifies an inbox behavior that cannot be implemented through extension points.

### 2. Kapso WhatsApp Cloud Inbox: best small official-API starter

**Fit.** The [Kapso inbox repository](https://github.com/gokapso/whatsapp-cloud-inbox) is an MIT-licensed Next.js inbox with text/media messaging, templates, interactive buttons, failure indicators, read-state UI, and 24-hour customer-service-window enforcement. Its focused codebase is much easier to understand than a full omnichannel platform.

**Official WhatsApp support and lock-in.** It targets the official Cloud API, but the documented default uses `KAPSO_API_KEY` and `https://api.kapso.ai/meta/whatsapp`; number discovery also calls Kapso. The endpoint is configurable, which reduces but does not eliminate migration work. Production adoption therefore requires reviewing Kapso's service terms, data path, pricing, availability, webhook guarantees, data residency, and an exit plan. The repository itself does not provide a self-hosted replacement for Kapso's control plane.

**License and activity.** The code is [MIT licensed](https://github.com/gokapso/whatsapp-cloud-inbox/blob/main/LICENSE). The [commit history](https://github.com/gokapso/whatsapp-cloud-inbox/commits/main) showed updates through 2026-04-11, but the repository had only 26 commits and no formal releases at review time. That indicates a useful starter, not a mature operational platform.

**Gaps.** There is no documented multi-user authorization model, assignment queue, human takeover state, contact/lead entity, AI orchestration, knowledge base, booking, alerts, audit trail, or production tenancy boundary. Auto-polling is also less robust than a durable event-driven inbox architecture.

**Decision: borrow or prototype.** Reuse its Cloud API message, template, media, policy-window, and inbox UI patterns. Do not mistake it for a production shared-inbox backend. A Kapso-based pilot is reasonable only if accepting a hosted dependency is intentional.

### 3. Frappe CRM ecosystem: strongest CRM-first alternative

**Fit.** [Frappe CRM](https://github.com/frappe/crm) offers lead, deal and contact entities, custom fields, views, activities, and assignment. Its [assignment rules](https://docs.frappe.io/crm/assignment-rule) support automated distribution, and its [deal model](https://docs.frappe.io/crm/deal) is closer to the PRD's lead lifecycle than a support ticket.

**WhatsApp support.** The CRM ecosystem points to [Frappe WhatsApp](https://github.com/shridarpatil/frappe_whatsapp), an MIT-licensed add-on using Meta's Cloud API with two-way messaging, templates, media, multiple accounts, webhooks, and Flows. However, the combined multi-agent shared-inbox experience is not as mature or cohesive as Chatwoot; an open [CRM shared-chat issue](https://github.com/frappe/crm/issues/2224) remained active in 2026. The older official [WABA integration](https://github.com/frappe/waba_integration) had been largely inactive since 2023 and should not anchor a new build.

**License and activity.** Frappe CRM is [AGPL-3.0](https://github.com/frappe/crm/blob/develop/LICENSE) and released [v1.81.2 on 2026-08-13](https://github.com/frappe/crm/releases/tag/v1.81.2). Add-ons use different licenses, including MIT and GPL, so the combined distribution and network-use obligations need legal review. Recent [security advisories](https://github.com/frappe/crm/security/advisories) also require staying current.

**Decision: conditional alternative.** Choose this only if the first product must be a broader CRM and the team accepts completing the inbox/handoff layer. For the current WhatsApp-first PRD, Chatwoot reaches the operational workflow faster.

### 4. Zammad: mature but support-ticket shaped

**Fit.** [Zammad](https://github.com/zammad/zammad) is a mature multi-agent helpdesk with users, groups, assignments, custom fields, permissions, and audit-oriented ticket workflows. It documents a direct [WhatsApp Cloud API channel](https://admin-docs.zammad.org/en/latest/channels/whatsapp/index.html). Its [ticket API](https://docs.zammad.org/en/latest/api/ticket/index.html) and [user API](https://docs.zammad.org/en/latest/api/user.html) allow an external qualification service to attach data and route work.

**License and activity.** Zammad is [AGPL-3.0](https://github.com/zammad/zammad/blob/develop/LICENSE). Commercial use is allowed, but modified network software brings source-code obligations that require legal review. [Zammad 7.1.2 was released on 2026-08-04](https://zammad.com/en/product/releases), and its [Docker deployment repository](https://github.com/zammad/zammad-docker-compose) is maintained. Its [security advisories](https://github.com/zammad/zammad/security/advisories) reinforce the need to remain on a supported release.

**Decision: integrate only for a helpdesk-first product.** It is production-capable, but mapping every lead interaction into a ticket introduces conceptual friction around lead quality, qualification evidence, booking, and sales follow-up.

### 5. Senqo: closest feature reference, disqualified transport

**Fit.** [Senqo](https://github.com/devennn/senqo) presents AI agents, a shared inbox, manual takeover, reusable knowledge, CRM, team access, bulk messaging, scheduled messaging, and a multi-workspace architecture. That makes it the closest product reference to `PRODUCT_REQUIREMENTS.md`. The repository also documents hundreds of automated tests and a sensible Node/React/PostgreSQL/S3 architecture.

**Critical disqualification.** Senqo's own README states that its WhatsApp service is a **Baileys session manager**, connects by scanning a QR code, and persists WhatsApp Web sessions. It is not the official Cloud API. This creates policy/account risk and operational exposure to session expiry, device linking, and reverse-engineered protocol changes. The software's MIT license does not make the WhatsApp connection method authorized or production-safe.

**Maturity.** At review time the repository had only 63 commits, 9 stars, no releases, and no published GitHub security policy/advisories. It may be thoughtfully built, but it is too young to outsource a revenue-critical messaging system to without a full independent security review.

**Decision: borrow patterns, never transport.** Study its inbox states, takeover controls, knowledge configuration, CRM views, workspace isolation, testing plan, and AI tool model. Do not deploy its Baileys service or connect a production WhatsApp number.

### 6. Dify: capable AI layer, unnecessary product core

**Fit.** [Dify](https://github.com/langgenius/dify) provides workflows, tools, model routing, retrieval/knowledge, evaluations, and human-in-the-loop patterns. It could orchestrate qualification and unanswered-question review, but it does not provide the required WhatsApp shared inbox, durable contact model, assignment workflow, or human takeover surface. A custom channel integration would still be required.

**License and activity.** Dify's [license](https://github.com/langgenius/dify/blob/main/LICENSE) is based on Apache 2.0 with additional conditions, including restrictions relevant to multi-tenant use and branding. Those conditions conflict with the intended evolution into a multi-client service unless a commercial agreement is obtained. The project released [v1.16.1 on 2026-07-28](https://github.com/langgenius/dify/releases/tag/v1.16.1) and is active.

**Decision: borrow workflow and knowledge patterns.** A small purpose-built qualification service will be easier to secure, test, operate, and resell. Consider Dify only for a time-boxed internal experiment, behind an interface and after license review.

### 7. Meta WhatsApp API Examples: authoritative samples only

**Fit.** Meta's [WhatsApp API examples](https://github.com/fbsamples/whatsapp-api-examples) demonstrate official Cloud API webhooks, message sending, templates, media, and signature handling. Meta also publishes the authoritative [Cloud API overview](https://developers.facebook.com/docs/whatsapp/cloud-api/overview), [webhook documentation](https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks), and [getting-started guide](https://developers.facebook.com/docs/whatsapp/cloud-api/get-started). The [Meta OpenAPI repository](https://github.com/facebook/openapi) is useful for generated clients and payload schemas.

**Limit.** These are examples, not an application foundation. They lack a shared inbox, authentication and roles, contact/lead storage, assignment, AI, booking, monitoring, durable retries, complete idempotency, audit, backups, and operational security. Their [sample license](https://github.com/fbsamples/whatsapp-api-examples/blob/main/LICENSE) is also tied to use with Facebook services/APIs rather than being a general permissive application license.

**Decision: borrow protocol patterns.** Use examples and official docs to verify webhook signatures, payload parsing, status transitions, templates, media, and policy-window behavior. Do not deploy samples as the backend.

### 8. Evolution API: unnecessary gateway with mixed transport risk

**Fit.** [Evolution API](https://github.com/evolution-foundation/evolution-api) can connect through the official Cloud API and integrates with Chatwoot, Dify, Typebot, and workflow tools. However, it also promotes Baileys-based WhatsApp-Web connectivity, which makes configuration mistakes and policy-risky deployments easier. It is an integration gateway, not the PRD's lead application.

**License and activity.** Its [license](https://github.com/evolution-foundation/evolution-api/blob/main/LICENSE) starts with Apache 2.0 but adds branding and usage-notification conditions, with commercial-license consequences. The latest stable reviewed was [v2.3.7 from 2025-12-05](https://github.com/evolution-foundation/evolution-api/releases/tag/v2.3.7); the 2.4 line remained prerelease in 2026.

**Decision: do not adopt.** Chatwoot already talks directly to the official Cloud API, so Evolution adds another credential boundary, database, queue, upgrade stream, and failure mode without solving qualification or lead workflow. Never use its Baileys mode for this product.

## Production Foundation vs. Samples and Unofficial Bridges

### Production-foundation candidates

- **Chatwoot:** recommended; production shared inbox with direct Cloud API and permissive Community Edition license.
- **Zammad:** production-capable, but its support-ticket model and AGPL obligations are less aligned.
- **Frappe CRM ecosystem:** production-capable components, but the official-API shared-inbox experience requires more assembly.

### Starters, sidecars, and pattern sources

- **Kapso WhatsApp Cloud Inbox:** official-API inbox starter; useful code, not a complete multi-user operations platform.
- **Dify:** AI workflow/knowledge sidecar; not an inbox or lead system, with material resale/multi-tenancy license concerns.
- **Meta examples:** authoritative protocol samples only.
- **Evolution API Cloud mode:** connector only; redundant for the recommended architecture.

### Unofficial WhatsApp-Web bridges: prohibited for production

- **Senqo's Baileys service** is unofficial despite the surrounding application's good product fit.
- [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js) explicitly describes itself as an unofficial WhatsApp Web client and warns that blocking cannot be guaranteed against.
- [WAHA](https://github.com/devlikeapro/waha) and Baileys-based modes similarly automate web/device sessions rather than use Meta's Cloud API.

The PRD should keep this as an architectural invariant: **no QR login, no linked-device session, no browser automation, and no reverse-engineered WhatsApp protocol in production.** A permissive code license does not remove Meta policy or account-enforcement risk.

## Security and Lock-In Requirements

Regardless of foundation, the implementation should require:

- Official Meta Cloud API credentials with least privilege, encrypted at rest and never exposed to the browser.
- Webhook signature verification, replay resistance, idempotency keys, deduplication, ordered processing per conversation, and retry/dead-letter handling.
- A durable automation state: `AI active`, `human requested`, `human assigned`, `human active`, and `AI resume approved`. A human reply must not race with the agent.
- Tenant scoping on every record from day one using `business_account_id`, even while the UI exposes one internal business.
- Role-based access, audit records for status/knowledge/assignment changes, sensitive-data redaction in logs, retention controls, backups, and restore testing.
- Canonical lead and qualification data in our database, not exclusively in an inbox vendor's custom fields.
- A channel adapter and normalized message schema so Chatwoot, Kapso, or direct Meta transport can be changed without rewriting qualification logic.
- Version pinning, dependency scanning, prompt/tool authorization tests, and rapid upstream security patching.
- Explicit handling of Meta's customer-service window, approved templates, opt-outs, quality limits, webhook delivery behavior, and pricing changes through official [WhatsApp Cloud API documentation](https://developers.facebook.com/docs/whatsapp/cloud-api/overview).

## Build/Fork Decision

**Do not build the inbox from zero, and do not fork a full platform on day one.** The highest-leverage path is:

1. Deploy Chatwoot Community Edition unchanged enough to follow upstream releases.
2. Connect one test number through the direct WhatsApp Cloud API channel.
3. Build a small AI Lead Employee service with its own multi-client-ready schema and Chatwoot adapter.
4. Implement human takeover before autonomous replies, then qualification, hot-lead alerts, and booking.
5. Mirror only operator-friendly summary fields into Chatwoot; keep evidence and decision history in our service.
6. Run the PRD's shadow-mode evaluation and launch gate against real internal conversations.
7. Fork or replace inbox code only after measured limitations justify ownership of that surface.

This retains the operational maturity of a maintained inbox while keeping the product's differentiating intelligence, customer data model, and future multi-client economics under our control.

## Final Shortlist by Intended Use

1. **Integrate:** [Chatwoot](https://github.com/chatwoot/chatwoot).
2. **Borrow/prototype:** [Kapso WhatsApp Cloud Inbox](https://github.com/gokapso/whatsapp-cloud-inbox).
3. **CRM-first alternative:** [Frappe CRM](https://github.com/frappe/crm) plus the official-API [Frappe WhatsApp add-on](https://github.com/shridarpatil/frappe_whatsapp).
4. **Helpdesk-first alternative:** [Zammad](https://github.com/zammad/zammad).
5. **Borrow product patterns only:** [Senqo](https://github.com/devennn/senqo).
6. **Borrow AI workflow patterns only:** [Dify](https://github.com/langgenius/dify).
7. **Borrow official protocol patterns only:** [Meta WhatsApp API Examples](https://github.com/fbsamples/whatsapp-api-examples).
8. **Reject as unnecessary gateway:** [Evolution API](https://github.com/evolution-foundation/evolution-api).
