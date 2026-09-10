# R05 integration preparation — 10 September 2026

Status: Implementation and focused verification completed on 10 September 2026
after the coordinator's explicit ownership handoff. R03 and R04 are accepted.
The focused branch is `codex/r05-natural-language-stop-20260910` at exact
baseline `324ee6df`; coordinator integration and in-app acceptance remain. This
document supersedes the earlier preparation against `5c3bbc2f`.

## Source and authority

- Inspected exact commit: `324ee6df9ca50dff708f41a4004cd105b23a784b`, on
  `codex/v1-completion-20260909`. Reads used that commit, not the shared working
  tree or this task's older detached checkout.
- Published acceptance: [issue 22](https://github.com/drsaidsaid/ai-chatbot/issues/22).
  Its comments were empty when refreshed on 10 September.
- Read current AGENTS.md, CONTEXT.md, PRODUCT_REQUIREMENTS.md,
  TECHNICAL_DESIGN.md, owned-inbox delivery guide, and ADRs 0002, 0009, 0010,
  0011. Earlier preparation covered ADRs 0005 and 0006 and the approved plan.
- R11's complaint/refund/support acknowledgement and precise human-request
  repairs, R09's qualification/context repairs, and R04's qualification lock
  regression are in progress per the coordinator. Their future interfaces are
  not present in the inspected source and are not assumed implemented here.
- ADR 0012 is reserved by R04. The coordinator reserved ADR 0013 for R05 after
  checking the integration, R10, and R11 documentation.

No Rails command, dependency installation, build, service, browser, or test was
run during preparation. The confirmed public tracer spec and shared product
documents may now change on the focused branch. Frozen audit evidence remains
untouched.

## Verified boundaries in the current source

| Boundary | Current behavior | R05 consequence |
| --- | --- | --- |
| `Whatsapp::EventProcessor` | A verified event and Channel lock enclose Message creation and processing completion. | Record a stop in this same transaction, before processing is marked complete. |
| `IncomingMessageWhatsappCloudService#record_orchestration_intent!` | Records a durable Channel Greeting, then an AI intent. | Run deterministic stop handling before both; an opt-out is processed even with AI paused, assigned, closed, or launch disabled. |
| `Whatsapp::OutboundEligibility` | Checks active `LeadFollowUpOptOut` existence immediately before automated Lead delivery. | Preserve this shared sending boundary and its existing active-row contract. |
| `LeadFollowUpOptOut#cancel_pending_automation` | On creation, invalidates work across all of the Lead's Account Conversations. | Reuse the R04 cancellation primitives under their lock order; do not rebuild a sender. |
| `Conversations::ControlService.invalidate_pending_ai!` | Cancels pending/claimed WhatsApp deliveries and blocks pending/processing AI intents. | Stop evidence and cancellation must commit together for already recorded automation. |
| `Whatsapp::OutboundDelivery` | Persists canceled outcomes into Message and domain outbox projections. Dispatching/unknown/accepted outcomes are distinct. | Display the persisted result; never claim to retract an already authorized send. |
| `AiLeadEmployee::OptOutService` | Still uses a narrow anchored regex, overwrites evidence on repeats, closes Qualification follow-up state, and directly cancels only this Conversation's follow-ups. | Replace these behaviors within R05; stop is separate from Qualification. |
| `AiLeadEmployee::AccessScope` | Team Members see assigned Conversations; Lead identity does not authorize all source evidence. | Expose operational suppression independently of Qualification, with separately authorized evidence. |

R04's authorization commit, changing claimed to dispatching, remains the precise
race boundary. If stop commits first, no new HTTP request may start. If dispatch
authorization commits first, the provider may still receive that request; its
accepted/unknown outcome remains accurate and later automated contact is blocked.

## Narrow implementation proposal

### 1. Deterministic stop recognition and transactional ingress

Add a focused stop/refusal recognizer owned by R05. It returns a structured result
and matched rule version without a model call. It consumes only persisted,
tenant-consistent, Lead-authored incoming text from the supported channel.
Private notes, outbound echoes, operator text, status updates and client-supplied
attributes cannot establish consent evidence.

Recognize explicit contact withdrawal in English, Swahili and mixed language,
including polite prefixes, punctuation, contractions and case variants. Positive
examples include `STOP`, `Please stop messaging me`, `Don't contact me again`,
`Tafadhali usinitumie ujumbe tena`, `Acha kunitumia ujumbe`, and
`Please usinitumie messages tena`. A bare refusal of budget or an answer is not
withdrawal. Negative examples include `No, my budget is not ready`,
`I don't want to stop receiving messages`, `Stop losing leads`,
`Sitaki kuacha kupokea ujumbe`, and quoted/reporting uses of stop instructions.
Ambiguous language does not silently grant consent or override an existing stop.

Call this service from the canonical Cloud incoming boundary, inside the verified
event transaction, before Channel Greeting or OrchestrationIntentRecorder. Stop
messages and later messages from a suppressed Lead do not create greeting or AI
reply work. Keep the recorder/worker's suppression checks as defense in depth,
including legacy/recovery entry points; none becomes an alternate ingress.

### 2. Durable evidence with a compatible active suppression projection

Retain `lead_follow_up_opt_outs` as the active suppression projection so R04's
existing existence checks remain correct. Add an immutable, Account/Lead-scoped
consent-event history for stop and explicit re-consent, with event/source Message
identity, source Conversation, trusted WhatsApp event identity, provider time,
receipt time, recorded time, observed wording, recognizer version and actor.
Consent concerns this V1 automated-contact purpose; this does not infer permission
for campaigns or a broader R15 nurture programme.

Deduplicate stop effects by canonical source identity. A duplicate event never
rewrites timestamps, evidence or Control State. A distinct later stop is a new
history event. Existing active rows are preserved and their available evidence
is archived before any supported re-consent; missing legacy evidence is labeled,
never invented. An active row is removed only by the evidenced re-consent
transaction, after preserving its history, never by AI resume or a generic edit.

Use Channel → owned Conversations in ID order → affected intent/delivery and
consent-record ordering compatible with ADR 0011. Invalidate the Lead's automation
across those Conversations and increment Control State versions without changing
ownership, assignment, Inbox status, Qualification, or its Follow-up State.
Consent withdrawal and reply ownership remain separate concepts.

The existing FollowUpDeliveryService locks a follow-up before a Conversation.
Do not introduce a Conversation → follow-up wait inside the stop transaction.
Commit suppression and delivery/intent invalidation without locking pending
follow-up rows. Late follow-up workers recheck consent and their observed Control
State version, then cancel themselves before recording an Outbound Message.
Recovery/re-consent must not revive any pre-stop attempt.

### 3. Explicit, evidenced re-consent

Proposed V1 action: an Admin selects a newer verified inbound Message that
explicitly asks to receive automated messages again, then records re-consent in
the Lead detail. There is no automatic reset from `hello`, `yes`, `START` embedded
in an unrelated sentence, an import, a support question, or AI resume.

The proposed Account-scoped mutation accepts a source Message ID and expected
latest stop-event ID. The server verifies current Admin membership, the same
Account/Lead/channel, explicit positive consent wording, freshness relative to
the latest stop and available trusted provider/receipt timestamps. Missing or
ambiguous ordering is rejected. A concurrent newer stop invalidates the action.
Replaying the same successful request is rejected because its evidence has
already been used. A delayed withdrawal that occurred before a newer grant is
retained as evidence without replacing that grant as current permission; replay
of an already processed stop has no new effect.

The transaction appends the evidence and actor, clears only the active suppression
projection, and advances Control State versions to invalidate old work. It sends
nothing and does not resume AI. Only a fresh subsequent eligible inbound message
or separately supported new scheduled action can produce work. Recorder guards
must reject replayed/late pre-consent source messages, even if a retry would form
a new idempotency key from the current control version. Previously canceled,
failed, unknown or claimed deliveries are never revived by re-consent.

### 4. Authorized operator views

Add a reusable consent payload to existing Conversation and Lead detail responses,
independent of whether a combined Qualification is visible. Show an unambiguous
automated-contact status and reason. Admins and operators with access to
the evidence Conversation can see the source/time and open the source Message.
For an assigned operator whose source is in an inaccessible Conversation, show
only the current consent state; omit source text, timestamps and IDs.
Reassignment and membership revocation apply to HTTP and realtime updates.

Keep re-consent separate from the existing AI resume control. Explain that resume
does not clear a stop. After re-consent, show the recorded evidence and current
consent state; do not promise that AI is active. Use the existing Rails/Vue
Inbox and Leads paths and R04's persisted delivery indicators.

## Ownership and integration contracts

| Owner | Boundary R05 will use | Overlap rule |
| --- | --- | --- |
| R04 | OutboundDelivery, OutboundEligibility, ControlService invalidation, sender outcome projections and authorization order | No sender rewrite or qualification lock edits. Preserve its active suppression predicate. Use the integrated regression fix before touching any shared orchestration seam. |
| R11 | Precise human/support classification and durable review creation | R05 owns stop recognition; R11 owns complaint/refund/support and human-request rules. Stop takes precedence over customer-facing acknowledgement. A complaint without withdrawal remains R11 behavior. Request a review-only, idempotent seam for mixed stop plus support, without generating an automated acknowledgement or invoking a model. Do not invent its eventual method name or edit the in-progress classifier. |
| R09 | Qualification extraction, question context and evaluation | Stop bypasses Qualification work; consent updates never close/re-evaluate Qualification. No parsing or qualification service edits. |
| R06 | Current AccessScope and assignment authority | Reuse it for payload/evidence/action authorization. Do not weaken assigned-only evidence access. |
| R15 | Follow-up generation, cadence and cancellation | R05 establishes active suppression and old-work invalidation. R15 retains scheduling redesign. Coordinate the generation/cutoff seam before shared follow-up changes. |

Current OutboundAlertAuthority also rejects alerts when the originating Lead is
opted out. R05 will preserve that integrated behavior; a local Review Request
must remain available in Inbox even when no WhatsApp alert is eligible. Any
different alert policy belongs to an explicit R11/R14 coordination decision.

## Proposed public acceptance seams

These are future acceptance checks, not results from this preparation.

| Scenario | Public boundary and observable proof |
| --- | --- |
| Natural-language stop | Signed `POST /webhooks/whatsapp/:phone_number` through receipt/event jobs. English, Swahili and mixed corpus produces durable evidence and no greeting, AI answer or provider POST; unrelated negations do not create suppression. |
| Active/pending contact | Start with real canonical queued AI/greeting/follow-up work, then ingress a stop. Run common SendReplyJob and recovery. Authorized Conversation messages report R04 canceled outcomes and the isolated provider receives no blocked send. |
| Atomic recovery | Kill an isolated worker before event commit, then recover the receipt. Message, stop evidence and effects commit once; processing cannot complete with missing consent. Replay separate envelopes containing the same provider Message ID. |
| Competing dispatch | Independent database workers barrier before R04 authorization commit: stop first blocks HTTP. Authorization first preserves accepted/unknown truth and blocks later work. Count isolated provider requests. |
| All Conversations | One Lead with several Conversations is suppressed across all of them, including a newly opened Conversation; another Account and another Lead remain unaffected. |
| Ownership and restart | Use existing assignment/takeover/pause/resume endpoints, restart isolated workers, and replay recovery. None removes consent suppression or revives canceled work. |
| Re-consent mutation | Proposed `POST /api/v1/accounts/:account_id/leads/:id/reconsent` rejects unauthorized actors, foreign/old/ambiguous evidence, stale expected stop and plain resume. Fresh explicit evidence records once; sends nothing; a later eligible inbound can proceed subject to every other gate. |
| Mixed support | Signed stop-plus-refund/support/human-request text records suppression and one local R11 Review Request through the agreed review-only seam; no customer-facing automated acknowledgement. Complaint-only controls retain R11 behavior. |
| Operator reads and UI | Existing `GET /api/v1/accounts/:account_id/conversations/:display_id`, its messages endpoint, and `GET /api/v1/accounts/:account_id/leads/:id` expose current status and only authorized evidence. Later inspect actual desktop/phone Inbox and Lead detail in R05's allocated in-app tab. |

Use dedicated synthetic Account/Lead data, an isolated database/queue, and the
existing R03/R04 fake-provider harness after resource allocation. No live customer
messages or launch activation are needed. Unit examples supplement these public
paths and never substitute for them. Run focused Rails and Vue behavior checks,
the required build, and real UI acceptance only after the explicit handoff.

### Coordinator UI handoff

Use the synthetic fixture contract in
`spec/requests/ai_lead_employee/automated_contact_consent_spec.rb`; its signed
webhook helpers create the Account, WhatsApp Inbox, Lead, Conversation, verified
provider event, stop evidence, and newer grant evidence without live Meta assets.
With the allocated local web and worker processes running against the migrated
branch database, inspect `/app/accounts/:account_id/conversations/:display_id`
and `/app/accounts/:account_id/leads?lead_id=:contact_id`. The Conversation and
Lead detail must show the withdrawn wording and time independently of
Qualification; Resume AI remains available when Control State permits and does
not clear the stop. After the administrator records the displayed newer grant,
both paths must show the granted wording and time and no re-consent action. Run
this only in the coordinator-allocated in-app browser tab.

## Implementation coordination

The coordinator confirmed public seams 1–4 and the mixed-message rule: stop
takes precedence, the incoming Message remains available to Human Operators, and
no automated acknowledgment is sent. Core R05 does not wait for or import the
unaccepted R11 candidate. A future accepted R11 integration may add a local
review hook without changing the consent interface.

Three coordinator-allocated test intervals used dedicated PostgreSQL and Redis
services and released them after use. The final post-review focused Rails matrix
passes 52 examples, including 11 current consent/concurrency/legacy-compatibility
examples. Focused Vue/API verification passes 23 tests; focused RuboCop, ESLint,
and normal commit hooks complete cleanly. No live provider, deployment, browser,
shared processor, or R11 candidate was used. R15 retains its later scheduling
redesign and must consume the active suppression and pre-withdrawal invalidation
contract. Do not close issue 22 until coordinator integration and in-app
acceptance.
