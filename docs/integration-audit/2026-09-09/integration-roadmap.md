# Online Profits integration design and delivery roadmap

9 September 2026 · Proposed decisions and tickets; no implementation authorized by this audit

## Product outcome and boundaries

Online Profits needs one reliable person history and several concurrent offer journeys, supported by a messaging assistant. The assistant should answer from approved OP information, help entry-offer buyers complete online steps, send relevant approved resources when appropriate, and involve Said, his wife, or an authorized coach only when there is a clear reason.

Preserve the Chatwoot Community Edition Rails/Vue runtime and its inbox conventions. OP remains its existing React/Supabase product. No parallel chatbot frontend, shared browser credential, direct cross-database access, or second Meta sender is needed. The existing OP WhatsApp sender should be disabled or routed through the single message authority during a later controlled cutover; it was not changed in this audit.

| Information or action | Authority | What the other system receives |
|---|---|---|
| Canonical Person and identity links | OP | Stable person ID, permitted display/profile fields, verified channel links |
| Offer catalogue and approved commercial facts | OP, owner-approved | Versioned offer facts, valid links/prices/currency/dates and approval references |
| Submissions, webinar registrations and offer participation | OP | Dated relevant events and a minimal current journey projection |
| Purchases, payment approval, refunds and disputes | Separate OP payment/verification boundary | Read-only verified status and permitted next action; no autonomous write authority |
| One-time access and program memberships | OP entitlement/enrollment boundary | Minimal access/support facts for the particular person and offer |
| Observed lifetime value | OP financial projection | Owner-authorized view only; excluded from general bot/coach context |
| Consent ledger | OP canonical ledger; both sides may receive and immediately enforce revocation | Purpose-specific effective state and evidence reference |
| Meta transport, message history and delivery | AI Lead Employee | Authorized timeline references and safe summaries/statuses |
| AI/human control, attention and message dispatch | AI Lead Employee | Control/attention facts linked to person and participation |
| Coaching assignment and allowed student scope | OP | A restricted program support projection, if needed |

Every derived field should display its source and freshness. “Unknown,” “not linked,” “waiting for verification,” and “sync delayed” are valid states; they must not silently become consent, payment success, or access approval.

## Canonical model

A **Person** has an immutable OP ID and can exist with no phone number. Names, emails, phone numbers, WhatsApp identifiers, authenticated OP user IDs, and source-record IDs are **IdentityLinks**, each with issuer/channel, normalized value, verification state, source, effective dates, and conflict status. Map an OP workspace to an AI Lead Employee BusinessAccount explicitly on the server.

A **Submission** remains a dated fact containing the form/version, source-record ID, submitted answers, and permission evidence. New submissions do not overwrite older ones. A **Touchpoint** records observed source context: landing page, UTM values, webinar/form, referral, timestamp, and confidence. Keep first observed touch and latest observed touch as derived fields, with the complete history available. “First observed” is not necessarily the customer’s first-ever interaction.

An **Offer** has a stable ID and approved versions. An **OfferParticipation** connects one person to one offer/cohort/cycle and owns the journey state, evidence, next action, and outcome history. A returning member gets a distinct renewal/cycle record where necessary. A **ConversationLink** connects a canonical conversation to a person and, when established, the relevant participation; a conversation can change topic without reassigning all historical facts.

A **Purchase** represents a verified commercial transaction/order outcome. Record provider/receipt IDs, amount/currency, payment approval reference, timestamps, refund/dispute links, and financial authority. Distinguish authorized/pending/approved/refunded/partially refunded/failed where supported. A screenshot or “nimelipa” is a payment claim requiring verification. It is not a PurchaseApproved event.

A **Membership/Enrollment** has program/cohort, start/end dates, status, and coach assignment. OPU, Mastermind, and Elite date-based participation must remain separate from perpetual or one-time product access. A person may have a one-time product and an active membership simultaneously. Renewal intent does not extend access; only the authorized membership/payment workflow does.

**Observed LTV** is a ledger-derived historical measure, not predicted future revenue. Show gross approved receipts, approved refunds/chargebacks, and net observed receipts by currency. Sum each verified financial movement once; do not count both an order total and its payments. Reversed/failed/pending receipts do not count as paid. Document treatment of installments, manual verification, and reporting period. Do not fabricate exchange rates or mix currencies into a single unlabeled value.

### Identity resolution and migration

Use verified issuer IDs and existing source links first. Exact normalized phone/email matches produce candidates; they are not universally sufficient to merge people. Shared family numbers, recycled numbers, typos, missing country code, business numbers, and conflicting authenticated accounts need explicit conflict handling. WhatsApp user IDs and phone numbers can differ. Anonymous browser identity is provisional until linked through a trusted action.

For a first unlinked inbound WhatsApp contact, create a provisional identity or request a canonical Person through the trusted bridge. Do not let an arbitrary browser supply another person’s OP ID. Verified source links can be automatic; ambiguous merges go to an owner review queue showing both histories. Keep an audited, reversible merge/link operation and aliases; never delete transaction history to resolve duplicates.

Backfill in a later authorized migration should:

1. Inventory actual deployed tables and constraints without assuming source migrations are applied.
2. Export a reversible mapping manifest in an isolated/staging environment; dry-run candidate links and conflict counts.
3. Create stable Person/source links first, then submissions, offer participation, purchases, and membership cycles without destructive overwrites.
4. Reconcile counts, source IDs, financial totals by currency, and unresolved conflicts. Historical missing conversations stay visibly missing.
5. Run incremental catch-up from durable source events and a watermark; switch readers only after parity and access tests pass.

Do not replay old submissions as fresh nurture or use old message ingestion time to reopen a WhatsApp response window. Meta’s general webhook API does not supply missing historical events on demand; recover from owned records or a separately supported, authorized migration/history mechanism and record coverage gaps.

## People, journeys, and Needs Attention

The People directory is the owner’s comprehensive authorized relationship view: identity, dated submissions, source history, linked conversations, concurrent offer participation, verified purchases/refunds, membership periods, and owner-only observed LTV. Paginate long timelines and show event time versus sync time. Search must preserve the same permissions as opening a record.

The Kanban represents **offer participation**, not one universal sales status per person. The same person can appear in an entry-course purchase journey and an OPU renewal journey without either overwriting the other. Cards show current stage, last meaningful evidence, next automated/human action, and owner only where work is assigned.

| Journey type | Example stages | Transition authority |
|---|---|---|
| Entry offer | Interested → Exploring → Checkout started → Payment pending verification → Purchased → Access delivered | Interest inferred with evidence; checkout event from OP; payment/access only from trusted services |
| Webinar | Registered → Confirmed/eligible → Attended or missed → Follow-up eligible → Outcome | Registration/access/attendance from actual webinar facts; eligibility requires consent/window checks |
| Program membership | Interested → Application/decision if required → Enrolled → Active → Renewal due → Renewed, expired or ended | Program rules, verified dates, approved payment/enrollment facts |
| Support | Requested → Assigned → Waiting on customer/internal action → Resolved | Authorized human or narrowly defined, verified support outcome |

These are proposed defaults, not invented existing OP policy. Avoid mandatory application/call stages for offers that sell directly. Abandoned, declined, refunded, or opted-out outcomes should remain visible without converting all of them into the same “lost lead” state. Marketing consent is an independent indicator.

Automated movement is legitimate when backed by an observed event or an explicitly labeled inference. Page views and ad clicks should not mark someone payment-ready. Manual stage corrections require a reason and source, while financial/access stages must be corrected through the owning service.

**Needs Attention** is a filtered work queue across these journeys. Create an item for an explicit human request, unresolved purchase/access problem, complaint/dispute, a meaningful decision the assistant cannot complete, an identity conflict, or a failed operational action that needs an owner. Each item has deduplication key, person/offer, reason, evidence excerpts/references, requested outcome, priority, assignee, due time, suggested response, and status. Separate content-maintenance tasks from customer requests. Repeated messages should update one open item, not generate repeated alerts.

For Said and his wife, prioritize actual requested help and high-value decisions. For Monibullah, show only authorized students and coaching information for his assigned programs. Keep prospects, unrelated conversations/purchases, owner notes, and LTV out of his responses, searches, counts, exports, notifications, and attachment access. Begin with the OP coaching view; do not create a generic chatbot agent account as a shortcut.

## Evidence-based assistance and nurture

Replace global BANT scoring with offer-specific evidence: customer goal, relevant obstacle/question, offer fit when known, explicit purchase intent, requested help, known eligibility facts, and next permissible action. Store polarity, confidence, source, and freshness. Prefer a reasoned status such as “asked for payment help today” over a bare numerical score. Missing evidence is unknown; negation must not count as positive evidence. Do not ask irrelevant business-owner questions of a course buyer.

Use Swahili and mixed-language examples from the actual business, including TZS amounts, local number formats, “sina bajeti,” “sihitaji sasa,” “nataka kujiunga,” “nimelipa,” “sijaweza kuingia,” and natural opt-out/human-request phrases. These are test candidates to review, not a complete language classifier. Persist preferred language when the customer states it; infer cautiously from recent conversation and allow correction.

The approved-content catalogue should include stable content ID and revision, offer/version, language, purpose, topic/objection, journey stages, eligibility, valid-from/until, canonical URL, owner approval, and whether it may be used reactively or proactively. Pricing/refund/access statements require authoritative structured facts. A content edit invalidates its prior approval or creates a new immutable revision.

Selection should answer the latest question first, respect the current offer and consent, avoid content recently sent, and record why the resource was chosen. Start with at most one useful resource per response, no repeated pitch after refusal, and an owner-set cadence cap. These are recommended product defaults; confirm cadence from observed value and complaints, not an assumed universal best time. Unknown offer or conflicting facts should prompt a brief clarification or a human review, not a confident guess.

Proactive nurture requires a persisted schedule, purpose permission, current offer/membership state, approved Meta template when outside the window, current template status/locale/parameters, and dispatch-time cancellation checks. Purchase, human takeover, assignment, opt-out, expired content, or changed eligibility should invalidate stale work. Resuming automation must not release a backlog of old pitches. Outbound marketing stops when the sequence reaches its approved limit or becomes irrelevant.

Payment help may explain approved methods and links, collect a claim reference, and create a verification request. The bot cannot approve payment, refund money, extend membership, or grant entitlement from conversation. Until a real calendar integration is proven, it can record a call request and tell the customer confirmation is pending.

## Server-to-server contract

Use two narrow adapters, one in OP’s server boundary and one in Rails. Each producer writes a durable outbox in the same transaction as the authoritative business fact; each consumer stores an inbox receipt with a unique event ID before acknowledging. At-least-once delivery plus idempotent handlers is the contract. Do not promise exactly-once network delivery.

A proposed event envelope:

```json
{
  "event_id": "opaque-unique-id",
  "schema_version": 1,
  "event_type": "offer_participation.updated",
  "producer": "online_profits",
  "workspace_id": "configured-op-workspace-id",
  "aggregate_type": "offer_participation",
  "aggregate_id": "stable-participation-id",
  "aggregate_version": 7,
  "person_id": "canonical-op-person-id",
  "offer_id": "approved-offer-id",
  "occurred_at": "RFC3339 source event time",
  "recorded_at": "RFC3339 source persistence time",
  "correlation_id": "opaque-journey-or-request-id",
  "causation_id": "prior-event-or-authorized-request-id",
  "evidence_ref": "authorized-source-reference",
  "payload": { "stage": "checkout_started" }
}
```

The receiver derives BusinessAccount from its server-held workspace mapping, not a client-supplied unrestricted account ID. Authenticate using a rotated service credential and HMAC over timestamp, request ID, method/path, and raw body, or an equivalently scoped authenticated transport. Check body size, schema, allowlisted event types, sender permissions, and signature freshness; keep a durable replay/idempotency record. Retries reuse the event ID but carry a fresh transport signature. Redact personal data and secrets from transport logs.

Use monotonic aggregate versions for order-sensitive projections. A duplicate is a no-op with a successful receipt; a gap is retained pending replay/snapshot reconciliation; a stale event stays in history without overwriting newer state. Out-of-order opt-out must not accidentally restore permission: re-consent requires its own valid later evidence. Quarantine invalid events, cap retries with backoff, expose dead-letter reasons, and allow audited redrive after repair.

Suggested facts from OP: person/identity linked or corrected; offer facts published; submission recorded; consent changed; participation changed; purchase approved/refunded; membership changed. Suggested facts from the inbox: conversation linked; permission revoked; attention requested/resolved; human control changed; message accepted/delivered/failed. Carry the minimum necessary fields; do not mirror all financial records or private conversations.

Keep **commands** distinct from facts: request an approved message, request a human review, request a permitted lookup, or request a link review. Commands have their own authorization, expiry, and idempotency; success means the owning service accepted the request, not that the business outcome occurred. A model-generated command is a proposal until validated by deterministic service rules.

For UI integration, begin with authenticated deep links and minimal projections. Full transcript access needs an authorized backend response or authenticated inbox session; never put credentials or unrestricted person IDs in public links. Deletion/retention requests must propagate to both systems with an audit record while preserving legitimately required financial records under the applicable policy.

## Messaging recovery and observability

Persist the authenticated envelope before a 200 response, then normalize every entry/change/message/status. Store provider timestamps, receipt times, routing account/inbox, payload hash, and processing state. Retain encrypted raw receipts for an owner-approved interval long enough to investigate the seven-day provider retry horizon; 30 days is an initial engineering proposal, not a legal retention requirement. Longer-lived normalized history should follow a documented business/privacy policy.

Use a unique outgoing action ID, atomic claim with lease expiry, and a common final eligibility check. Preserve provider message ID and, where supported, a non-PII callback correlation value. On a timeout after possible acceptance, mark unknown, seek status correlation, and raise one attention item if unresolved. Avoid blind retry that could charge/send twice. Recipient delivery/read facts remain separate from local accepted status.

Prove recovery after crashes before/after receipt, normalized message commit, intent creation, queue enqueue, model response, outbox claim, provider response, and local status commit. Never hold conversation locks across slow provider work. Cancel unsent AI work on takeover; on recovery re-evaluate age, consent, control, and relevance instead of replaying every old action.

Monitor receipt/normalization lag, queue depth/age, lease expiry, retry/dead-letter count, duplicate prevention, unknown acceptance, delivery failures by provider code, token health, template quality, opt-outs, owner attention age, response quality by language/offer, cost, and sync reconciliation gaps. Redact bodies/credentials from operational alerts. Prefer owner-visible dashboards and grouped actionable alerts over per-message noise.

## Proposed tracer-bullet tickets

Each ticket below is a draft for later implementation. Follow the repository’s existing delivery flow: settle CONTEXT/PRD/design/ADR decisions, then create focused tickets, drive behavior test-first, run relevant checks/build, review, and commit only when implementation is authorized. Effort is a rough focused engineering range, not a deadline or a deployment promise; access/setup and failures can extend it.

| Ticket | Demonstrable path and scope | Blockers | Acceptance evidence | Rough effort |
|---|---|---|---|---|
| INT-00 | Reconcile task/root/QA/RC and record one release base; retain useful donor work without parallel runtime | None | Clean disposable build from selected SHA; schema-load and migration parity; CE/license/package checks; source/proof index current | 1–2 days |
| INT-01 | Authenticated Meta event becomes one durable correctly routed message | INT-00 | Missing/invalid signatures rejected; global/manual/embedded setup; multi-entry/change/sender batches; duplicate/crash/replay; old timestamps; no cross-tenant writes | 2–4 days |
| INT-02 | One eligible automated reply dispatches once or becomes an explicit unknown/failed outcome | INT-01 | Two-worker race; takeover/assignment/opt-out/gate withdrawal at every boundary; lease recovery; bounded retries; status before local ID; no read→sent regression | 3–5 days |
| INT-03 | A natural-language opt-out stops pending automation and appears in a purpose ledger | INT-01; final sending acceptance depends on INT-02 | Live canonical path, English/Swahili/mixed phrases, repeated revoke, later re-consent, stale event, window/template separation | 2–3 days |
| INT-04 | One Person has two offer journeys and dated source history without overwrites | INT-00; contract ADR | Phone-optional person; verified links; shared/recycled phone conflicts; repeated submissions; purchases and memberships distinct; reversible backfill dry-run | 3–5 days |
| INT-05 | OP fact reaches the inbox and an opt-out/attention fact returns through the bridge | INT-02/03/04 | Signed scope checks, duplicate/out-of-order/gaps, crash retries, dead letters, schema version change, snapshot reconciliation, no parallel sender | 3–5 days |
| INT-06 | Owner sees full authorized person journey; coach sees only assigned program support | INT-04/05 | API/RLS/search/export/attachment/websocket negative tests; no prospect/LTV leakage; multi-offer Kanban and small evidence-backed attention queue | 3–5 days |
| INT-07 | Swahili entry buyer receives the correct approved answer/checkout route; support request reaches a human | INT-03/04 | Negation/TZS regression cases; no generic BANT barrier; offer isolation, human request, complaint, knowledge conflict/injection, bounded memory; no payment/access/booking fabrication | 3–5 days |
| INT-08 | Approved state facts support payment/access questions without granting model authority | INT-05/06/07; payment boundary confirmed | Claimed versus verified payment; partial refund/installments; duplicate financial events counted once; membership dates; owner/coach field restrictions; provider failure fallback | 2–4 days |
| INT-09 | Current release passes held-out evaluation and a supervised pilot | INT-01/02/03/05/06/07; INT-08 for money/access use | Release-bound evidence, relevant Rails/Vue/build checks, crash/control/permission suite, authorized Meta test assets, owner review and rollback rehearsal | 2–3 engineering days plus observation |
| INT-10 | One consented offer sequence sends relevant approved nurture and stops correctly | INT-09; approved templates/content/cadence | Real scheduler path, dry-run explanation, template rejection/pause, purchase/opt-out/takeover cancellation, expiry/cap, no stale backlog on resume | 3–5 days |

INT-00 through INT-03 close foundational risks; INT-04 onward adds the business integration. Work can be split across the two repositories after the contract is fixed, but no subagents, new tasks, or implementation branches were created during this audit. The full programme should not be assumed to fit before September 25.

## Evaluation and rollout gates

A launch record should bind commit, database migration set, model/provider configuration, system prompt, retrieval/knowledge revisions, qualification rules, and template configuration. Material changes invalidate affected evidence. Keep newest failing/unreviewed results visible rather than selecting older reviewed passes. Record actual reviewed conversation IDs, reviewer, rubric, and issues; an editable pilot count is insufficient.

Proposed held-out matrix: new/repeat/ambiguous identity; each active offer and membership cycle; Swahili/English/mixed language; ordinary inquiry, clear buying intent, negation, payment claim, access failure, refund request, explicit human request, stop request, stale content, conflicting sources, injection, media/unsupported content, provider failure, delayed/duplicate/out-of-order events, and cross-role access. Evaluate realistic multi-turn conversations, not only isolated prompts.

Zero tolerated severe failures: cross-person/account disclosure, coach scope breach, ignored opt-out/takeover, unauthorized financial/access action, fabricated payment/booking/access/price claim, and duplicate dispatch in controlled concurrency tests. Measure useful answer accuracy, offer attribution, escalation precision/recall, and language quality separately. A proposed target is at least 95% correctly supported answers and at least 95% correct attention routing on a reviewed held-out set, with zero severe cases; these are engineering acceptance proposals, not statistical guarantees. Investigate every false negative on an explicit help request.

Begin with offline replay, then shadow decisions with no messages, then reviewed drafts. A later owner-approved live pilot should have small volume, supervised availability, an immediate pause, daily review, and at least 20–30 diverse conversations over several days before expansion. Coverage matters more than a raw count. Restrict the first pilot to approved reactive questions; payment/access topics and proactive nurture require their own gates. Real Meta test messages and paid evaluations need their own explicit authorization; none were performed here.

A rollback should disable automated creation and dispatch while preserving human inbox access, receipts, and history. Pausing the model alone is not enough because queued outbox work may still send. Test the pause at dispatch, preserve unresolved events, notify the responsible owner once, and require revalidation before resume. Do not mass-replay old messages.

## September 25 path

Keep a separate webinar readiness checklist for registration/confirmation, actual session schedule/link, verified offer information, payment verification, access, and a clear support route. Use current approved facts; this audit does not establish the session time, platform account setup, or payment readiness. Respect existing channel permission when sending any reminder.

The webinar can proceed without chatbot integration. Prefer website instructions, the established manual verification process, and human support while the bot remains disabled. An automated AI pilot is optional and should be excluded if its gates are incomplete. A human inbox pilot also needs authenticated durable ingress, correct secrets, tested access, and proven sending controls; “human-only” does not remove transport defects. Do not migrate all customers or activate nurture to meet the webinar date.

After the webinar, use actual consented support questions and observed outcomes to refine the catalogue and journey rules. Expand only when the release evidence, owner workload, and customer outcomes support it.
