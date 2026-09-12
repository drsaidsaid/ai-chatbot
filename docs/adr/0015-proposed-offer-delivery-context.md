---
status: accepted
---

# Frozen Offer delivery context and selection revision

Accepted by the coordinator after complete-source reader review of e7601952 and
its59/0 reproduction. The decision includes the complete caller lock matrix,
batch lock ranks, monotonic admission and immutable replacement lineage below.
The previously frozen proposal remains historical evidence; acceptance authorizes
two reviewed implementation increments, not a claim that runtime already complies.
First implement normal reply and handoff context/fences; then implement logical
attempts, follow-up replacement and every remaining ordered lifecycle caller.
Vue, R07 controls and deployment are outside this allocation.

## Problem

A queued qualification-dependent output can outlive its Offer configuration,
Conversation selection or supporting evidence. Comparing only the current Offer
id permits selecting A → B → A to revive output from the first A selection.
Comparing only the Offer configuration version misses a human evidence correction
that produces a new decision without changing configuration. Reading the current
LeadQualification row at send time cannot recover which immutable decision
produced the queued content.

## Decision

Add a monotonically increasing `offer_selection_version` to Conversation. Default
0 denotes no observed selection transition. Increment under the Conversation lock
whenever selection actually changes, including automatic sole-Offer selection,
selection removal and switching away/back. Idempotently selecting the same Offer
does not increment it. Do not repurpose `control_version`: selection and AI/Human
control remain distinct authorities and both must still match.

Capture a frozen qualification context while evaluating under Conversation →
Offer → Contact → Qualification locks. Record the immutable qualification decision
first and return that decision's identity in the Result used to create content.
Frozen nested context:

```json
{
  "scope": "offer",
  "account_id": 1,
  "contact_id": 2,
  "origin_conversation_id": 3,
  "offer_id": 4,
  "selection_version": 5,
  "configuration_version": 6,
  "qualification_id": 7,
  "decision_id": 8,
  "next_question_key": "budget"
}
```

The context's configuration_version remains the Offer revision, preserving the
existing qualification metadata meaning. Provider configuration/day metadata and
observed_control_version remain separate existing fields. IDs above illustrate
shape only. No context field may be inferred from a different/latest Conversation.

Copy the same frozen context to the persisted Message, OutboxEvent, scheduled
follow-up and handoff snapshot/alert that depend on the decision. A follow-up's
context must be captured when scheduled, not reconstructed from its mutable
Qualification association. The alert context references the originating Lead
Conversation, not the operator notification Conversation. Retries reuse original
content/context; they cannot adopt a newer revision to make old content eligible.

Legacy unscoped history remains labeled `legacy_unscoped`. Never backfill old
queued artifacts with a currently sole Offer or invent decision/selection versions.
A legacy artifact's allowed behavior must be explicit: if no Offers exist, retain
its accepted legacy gates; once Offer-scoped operation applies to that originating
Conversation, missing scoped authority is canceled/held rather than silently
converted. Human-authored messages and genuinely non-qualification-dependent
outputs are not given synthetic qualification dependencies.

## Final authority

At the canonical dispatching transition, verify scope/account/contact/origin,
current selected Offer id and selection version, enabled Offer and configuration
revision, the same current Qualification and immutable decision, and absence of
staleness. A newer evaluation or human correction must not revive a prior context.
Use a stable cancellation reason for selection/configuration/decision mismatch.
Do not modify original observations, content or historical decision snapshots.

Offer authority is conjunctive with existing account/connection/launch/control/
assignment/consent/provider-day/provider-configuration/allowance/window/template/
recipient/domain checks. It never grants consent, resets allowance, permits a
terminal retry or replaces R10's metered provider client.

The dispatching commit is the admission boundary. If an Offer edit/selection/
evidence correction commits first, the old output sends zero times. If final
authorization commits first, the already admitted request may complete once;
a later edit cannot retroactively unsend it. HTTP remains outside authority locks.
Unknown acceptance remains unknown and never gains an automatic retry through a
new context. A fresh context does not recycle canceled/failed/unknown Message IDs.

## Required lock order

Desired relative order is Channel → owned Conversations in stable id order →
origin Offer → dependent domain/qualification/delivery records, reconciled with
all participating code. Evaluation is Conversation → Offer → Contact →
Qualification; configuration editing is Offer → qualification invalidation.
Do not hold Offer and then acquire a previously unlocked Conversation.

Private R04 patch `59a3bbf` is not integrated into accepted base9a. It changes
LeadUpdateService and three IntentProcessor non-key lock clauses, not
FollowUpDeliveryService. Import no private ancestry. Any narrowly needed lock
clause must be justified by current-source regression evidence. The matrix below
is the accepted target; its implementation must be demonstrated incrementally.

## Follow-up identity and migration

Per-Offer follow-ups must not share the account/contact/stage/attempt key. The
logical-attempt aggregate, immutable artifact lineage, partial uniqueness and
conservative historical backfill specified below are the accepted migration
contract. Revisions cannot reset attempt budgets or rewrite artifact context.

## Required proof and affected files

Start from actual recorded Messages/outbox rows and scheduled attempts, with
real database-worker interleavings around the final authorization transaction.
Prove edit-first versus admission-first, A→B→A, changed evidence at the same
configuration revision, disabled/deleted selection, and unchanged/unrelated-Offer
positive controls. Repeat jobs must preserve once-only, rejected and unknown
semantics. Handoff tests must cover both pre-assignment invalidation and queued
operator alerts after configuration/evidence changes. Preserve R06 and all R10,
consent and control regressions named in the delivery preparation plan.

Affected paths are listed in
`docs/issues/v1-completion-20260909/r09-readers-delivery-preparation.md`.
Migration(s), selection writers, decision capture, attempt identity and canonical
delivery locks must satisfy this decision and their allocated increment's tests.
Freeze the first increment for coordinator review before expanding the second.
Vue and R07 cockpit/control behavior remain outside this allocation.

## Replacement lineage and indexes

Use a durable logical-attempt aggregate and immutable artifact rows:

- New `lead_follow_up_attempts` owns account_id, contact_id, nullable offer_id,
  stage, attempt_number, current_follow_up_id, admission_state and admitted_at.
  Admission states are unadmitted, admitted, accepted, unknown, failed and blocked.
  State never returns from any of the latter five to unadmitted. admitted_at,
  once present, never clears. Control/consent cancellation changes an unadmitted
  attempt to blocked, so later configuration changes cannot recycle it.
- Unique `(account_id, contact_id, offer_id, stage, attempt_number)` for nonnull
  Offer; a separate partial unique `(account_id, contact_id, stage, attempt_number)`
  for null Offer. Neither key includes configuration/selection/decision revision.
  Thus each Offer retains its stage/attempt budget across all revisions.
- Each `lead_follow_ups` row becomes one immutable content/context artifact for
  an attempt: required attempt_id, frozen qualification_context, nullable
  replaces_follow_up_id, replaced_by_follow_up_id, superseded_at and
  replacement_reason. Add unique replaces_follow_up_id when nonnull and a partial
  unique attempt_id where superseded_at IS NULL. One artifact can have at most
  one successor, and each logical attempt has one unsuperseded artifact.
  Foreign keys and a same-attempt lineage validation reject cross-Offer lineage.
- Retain existing content, question and timestamps as historical data. Content,
  question key, origin, frozen context and lineage predecessor cannot be changed
  after artifact creation. Only delivery lifecycle and recorded supersession
  status change. The attempt's current pointer advances atomically to a newly
  inserted artifact; it never points backwards to reuse an old Message.

An ordinary newly eligible scheduling decision may request replacement; an Offer
edit or cancellation alone does not send or schedule a replacement. In one
transaction, lock the originating Conversation, Offer, logical attempt, current
artifact, and its Message delivery (if present), in the reviewed order compatible
with final dispatch. Require all of the following before replacing:

1. The attempt is still unadmitted with admitted_at absent, its current pointer
   matches the artifact being superseded, and no artifact in this lineage ever
   crossed dispatching or admission. Check durable admission state, not a stale
   in-memory FollowUp status.
2. The artifact is pending, or was canceled **solely** with an exact Offer-context
   mismatch reason: offer_configuration_changed, offer_selection_changed, or
   qualification_decision_changed. Cancellation for control, assignment, consent,
   opt-out, provider failure, delivery failure, operator action or any unknown
   reason is ineligible. Failed artifacts are ineligible even if failure happened
   during preparation; sent/dispatching/accepted/unknown artifacts are ineligible.
3. A materialized delivery has no dispatch_started_at and is pending/claimed, or
   canceled with the same allowed context reason. A claimed worker cannot retain
   permission: cancellation clears its lease/owner eligibility under the delivery
   lock before the replacement is published. A queued worker still addresses the
   old artifact/Message and fails the current-pointer/context check.
4. A fresh qualification decision for the same account/Lead/Offer/stage and same
   originating Conversation is independently eligible now, under its current
   selection revision, Offer revision, consent and control. No synthetic new
   decision is manufactured merely to obtain a new attempt.

Mark the predecessor superseded with a specific reason and successor id, preserve
its original context, and cancel its never-admitted Message/outbox record without
resetting terminal states. Insert the new artifact with a new Message identity
when eventually materialized, the same logical attempt_number, the explicit
predecessor link and the freshly captured context. Atomically update the attempt
pointer. Competing schedulers serialize on the aggregate; uniqueness supplies a
second defense against forks. A retry observes the existing successor instead of
creating another one.

Final dispatch acquires the logical-attempt lock before its artifact/delivery
locks, verifies that the artifact is still current and unsuperseded, and writes
attempt admission_state=admitted/admitted_at in the **same transaction** as the
Message delivery's dispatching transition. Subsequent provider outcome advances
the aggregate to accepted/unknown/failed, preserving admitted_at. If admission
wins the race, replacement is forbidden; if replacement wins, the old worker
cannot send. A once-admitted attempt consumes its existing stage budget regardless
of Offer revision or later human correction. A canceled blocked attempt is not
silently reopened by reconsent; any separately authorized future outreach follows
its own reviewed policy and cannot reuse this attempt under a revision change.

Migration creates one aggregate per existing historical logical key using the
Offer already recorded on its Qualification, if any; unscoped records stay null.
Retain every existing artifact id and original source relationship. Initialize
admission conservatively from actual Message delivery/history: any dispatching,
sent/accepted, unknown or failed record is nonreplaceable; old cancellation is
blocked unless its recorded reason and durable history prove the narrow context-
only never-admitted case. Missing proof never becomes a replacement entitlement.
Remove the old account/contact-only uniqueness only after the new aggregate and
artifact constraints are populated and verified.

Required additional tests: concurrent replacement cannot fork lineage; an old
queued job cannot follow the new pointer to send new content; Offer A replacement
does not consume or replace Offer B; stage/attempt counts do not reset across
many revisions; each terminal/admitted/control/consent case denies replacement;
context-only never-admitted replacement succeeds once with original predecessor
history intact. Each implementation increment requires actual red/green evidence
and a complete immutable source snapshot before review.

## Caller lock matrix: publication and every outcome path

This matrix addresses the concrete inversion present in the complete reader source.
Current `OutboundDispatch#accept` locks Delivery, then `publish!` locks Message,
then `publish_outbox!` updates OutboxEvent and `mark_follow_up_sent!` updates the
FollowUp artifact. Adding an Attempt update there would produce
Delivery → Message → Outbox → Artifact → Attempt. Materialization/replacement
would take the opposite direction. This is forbidden by this decision.
The following matrix is the required implementation contract, not a claim that
current runtime already satisfies it.

### Lock ranks and entry-point rules

Notation: `C` = only required owned Conversations, locked together in ascending id;
`O` = required originating Offers in ascending id; `R` = an existing review or
other originating domain-authority record; `A` = logical follow-up Attempt;
`F` = immutable FollowUp artifact; `D` = canonical WhatsApp Delivery; `M` = Message;
`E` = OutboxEvent rows in ascending id. `A/F` are omitted for non-follow-up outputs,
never fabricated from the currently selected Offer. For batches, acquire all Attempts first, then all artifacts, then all deliveries,
then all Messages and OutboxEvents, each rank in ascending id order.

The shared suffix is always **A → F → D → M → E**. All C/O and any required
originating authority locks precede this suffix. A writer may use a suffix alone
when it does not need current Conversation/Offer authority. No code holding a
later lock may acquire an earlier missing one, including implicit locks from
UPDATE, foreign keys, callbacks or association helpers. Reading an immutable id
without FOR UPDATE to discover lock targets is allowed; verify those ids and
account/contact/origin relationships again after ordered locks are held. If the
association no longer matches, release the entire transaction and restart; never
follow a changed pointer while holding a later lock.

Resolve an old job's original F from its immutable Message/artifact relationship,
then resolve A from F. Do not resolve F from A.current_follow_up_id and accidentally
let an old job send the successor. Under A/F locks, compare the current pointer
and supersession/context before any admission. Newly inserted, uncommitted rows
are not shared lock targets: materialization may insert a fresh M whose existing
after_create hook inserts a fresh D, but it already owns A/F and never locks an
existing earlier row after those inserts. Once visible, D-before-M applies.

Introduce explicit high-level ordered lifecycle entry points. Locked transition
helpers receive the already-owned A/F/D context and never call a public wrapper
that tries to acquire missing earlier locks. Delivery-only `claim` remains a
short independent transaction and may only update the D lease/count; it must not
call publication, Artifact/Attempt updates, review creation, current-pointer
checks requiring locks, cancellation or any earlier authority helper.

Refactor `publish!`/`publish_outbox!` to **projection only**: update M then E from
an already resolved D state. Remove `mark_follow_up_sent!` from publication.
The high-level accept/reconcile operation updates F and A under locks acquired
before D. A shared publisher must never discover or lock A/F/R from an event
payload. Even idempotent publication uses the ordered owner entry point when
associated domain projection is needed; public delivery.with_lock { publish! }
call sites cannot remain as a shortcut that later grows domain side effects.

| Caller / entry path | Required acquired locks and transition | Current code change required before implementation acceptance |
| --- | --- | --- |
| FollowUpScheduler creation/materialization preparation | C → O → A → F; new artifact inserts preserve frozen context. Materialization of an existing artifact adds D → M → E if any existing delivery is touched. | Remove FollowUp-first entry. Resolve/create logical Attempt under its unique key; do not mutate predecessor content/context. |
| FollowUpDeliveryService.perform/record_follow_up! including opt-out, state, due-time and internal-note branches | C → O → A → F → D → M → E as needed; recheck eligibility before new M/D inserts. | Its present outer follow_up.with_lock followed by Conversation is inverted. Every early cancellation/reschedule branch must enter through ordered owner, not recursively call public cancel! while F alone is held. |
| Context-only replacement | C → O → A → current F → predecessor D → M → E; insert new F/new context and atomically advance pointer while A held. | Keep original job/artifact identity and narrow never-admitted eligibility. Competing successors serialize on A and unique lineage. No new earlier locks after predecessor D/M/E. |
| OutboundDispatch.claim | D only, commit before later phases. | Preserve lease/count ownership only. No publish/domain/authority calls while D is held. |
| OutboundDispatch.authorize, including greeting_ready? cancellation/requeue and eligibility failure | Channel → C → O → required provider/membership/origin authority R → A → F → D → M → E. | Pre-resolve and lock A/F before D. Prelock alert authority record before D rather than OutboundAlertAuthority.failure_code acquiring R afterward. Perform atomic attempt admitted_at/state and D dispatching transition under the same lock set. Existing provider/control/consent checks remain conjunctive. Greeting-only D changes use this same entry and projection helper. |
| OutboundDispatch.accept | C for the delivery's review Conversation → existing delivery_unknown review R rows in id order → A → F → D → M → E. No Channel or O reacquisition. | C is needed here specifically to serialize creation/resolution of the local unknown-delivery review with record_unknown!. Lock R before A/D, resolve it after acceptance with locks already owned. Record receipt/source id, advance admitted aggregate and mark F sent in the owner operation, not publish!. Never reassess a later Offer edit to reject an already admitted provider acceptance. |
| OutboundDispatch.fail! (definite provider rejection) | A → F → D → M → E; no C/O unless an independent required action is identified before entry. | Replace current D-first update/publication. Aggregate becomes nonreplaceable failed, preserving admitted_at; no retry permission is created. |
| OutboundDispatch.unknown! / OutboundDelivery.record_unknown! | C for the local review → existing delivery_unknown R → A → F → D → M → E. New R may be inserted under already-owned C after the state transition; it is a fresh row, not an earlier shared lock. | Owner/dispatching check plus unknown state, aggregate unknown and idempotent local review are one transaction. C serializes absence/creation of R with accept cleanup. No HTTP retry and no backwards admission transition. |
| OutboundDelivery.recover! from OutboundRecoveryJob | Read ids/state without locks, then C/R prefix for a possible unknown-review transition → A → F → D → M → E. | All lease states rechecked under D after A/F acquired. Expired dispatching becomes unknown, never pending. Expired claimed can requeue only the same original still-current artifact within existing MAX_CLAIM_ATTEMPTS; otherwise cancel/fail without a replacement entitlement. Even pending recovery must verify current artifact before requeue. |
| OutboundDelivery.recover_claim! exhaustion | Already-owned ordered recovery context A/F/D; M → E projection only. | Mark failed/nonreplaceable at existing claim cap. No isolated D-lock call that updates F/A afterward. |
| fail_preparation! from SendOnWhatsappService rescue or OutboundDispatch.perform rescue | Fresh A → F → D → M → E entry after unwinding any failed previous transaction. | Preserve pending/claimed+owner checks, mark nonreplaceable failed even if never admitted. Do not call while an abandoned D/M/outbox lock remains held. Failure handling must not reinterpret an error as a context-only replacement. |
| OutboxDispatchJob.dispatch post-send publication repair | A → F → D → M → E through the idempotent lifecycle reconciliation entry, after SendReplyJob returns. | Replace current delivery.with_lock { delivery.publish! }. Reconcile accepted F/A only with their locks already acquired; publisher itself stays domain-free. Bad/missing/cross-account event payload only marks E failed and acquires no earlier lock afterward. |
| OutboundDelivery.cancel_automation! under ControlService, AssignmentService or provider invalidation | Inherited C if already held; O → A → F → D → M → E for affected originals. A standalone call obtains its required C first. | Replace delivery-first loop. Only pending/claimed never-admitted deliveries are canceled; mark Attempt blocked for control/consent/provider reasons. Never cancel/recycle an already admitted request. Process stable groups; if a caller already owns one C, do not acquire another lower-id C. Notification C need not be acquired merely to update its Message projection. |
| FollowUpScheduler.cancel_pending_for! / LeadFollowUp.cancel! from scheduler, OptOutService, Conversation status callbacks, AssignmentService, ControlService, or LeadQualification callback | C → O → A → F → D → M → E, omitting D/M/E when no Message exists. A caller with an owned prefix passes it explicitly. | Public cancellation must resolve A before F. All call sites currently updating F directly migrate together. Control/consent/internal-note/operator cancellation sets blocked, never context-replaceable. Ordinary no-question/completed-stage cancellation is not relabeled as context-only. |
| AutomatedContactConsent.record_inbound!/grant! → invalidate_automation! | Retain Channel → all owned C in stable order; prelock all affected O, then preserve consent row/event serialization → A → F → D → M → E for invalidated artifacts. | Existing shared C ownership serializes consent versus final admission. Never acquire additional C while holding A/F/D. Grant still invalidates old work; reconsent does not reopen consumed/blocked attempts. Preserve current provider-day and opt-out semantics. |
| OfferConfigurationWriter invalidation / Offer selection writer | Configuration writer: O → Qualification invalidation only, no C/domain suffix. After commit, if eager cancellation is wanted, start new C → O → A → F → D → M → E transaction. Selection writer already owns C, then ordered old/new O before suffix. | Config writer must not call a cancellation wrapper that acquires Conversations while O is held. Staleness + final O-version check supplies immediate safety even before a post-commit cleanup. Avoid after-save callbacks that secretly acquire earlier C. |
| OutboundDelivery.retry_for? from MessagesController.retry | C → O if scoped → required membership authority → A → F → D → M → E. | Preserve ordinary authorized human-message retry behavior. For Offer follow-up artifacts, a failed/unknown/admitted/blocked attempt cannot become a new pending artifact by this endpoint; reject rather than reset A or recycle F. Any explicit future outreach needs separately authorized fresh work within its budget. |
| MessageStatusProjector via canonical DeliveryStatusProjector/EventProcessor or legacy process_statuses | Existing webhook-event/Channel ownership may prefix receipt work; synchronize recipient aliases before locking M, then M rows in ascending id only. No A/F/D/E publication. | Provider sent/delivered/read/failed projection remains distinct from canonical provider acceptance. It cannot lower Attempt admission or create retries. Canonical DeliveryStatusProjector currently locks M before alias sync; move needed alias/FK work before M if it can acquire earlier identity locks. Do not append domain updates to Message's status callback. |

### Review, publication and callback audit details

The audited delivery publication call sites are OutboundDispatch authorize success
and rejection, greeting_ready?, accept, fail and unknown; OutboundDelivery unknown,
preparation failure, retry, cancel_automation and recover_claim exhaustion; and
OutboxDispatchJob post-send repair. `KnowledgeDocument#publish!` is unrelated and
outside this audit. Every listed delivery call site must migrate with the publisher;
changing only accept or the canonical happy path is insufficient.

Accept/unknown use C/R before the shared suffix because current semantics require
exactly one local unknown-delivery review and resolution on a later accepted
receipt. Neither path calls HumanReviewRequest.resolve! to manufacture a human
message; direct existing review status updates occur on prelocked R. If review
membership is discovered late after D is held, abort and restart with the complete
C/R prefix; never acquire R/C while retaining D/M/E. The shared C serializes a
missing review row's creation. Provider callbacks remain M-only, so they cannot
form M → A/F/D cycles or mistakenly turn provider status into a second admission.

Message after_create inserts a fresh canonical Delivery; after_create_commit
callbacks reopen/update activity/send queue events only after the materialization
transaction releases A/F/D. An outbox-managed Message still suppresses automatic
SendReply scheduling until its durable event exists. Message updates used by
publication run only projection callbacks; no new domain writes may be added to
those callbacks. Conversation.after_update can invoke cancellation before commit,
so its caller must pass already-owned C and obtain O/A/F before any Delivery.
Conversation.after_update_commit and LeadQualification.after_update_commit
cancellation restart at the proper prefix after outer locks release. In tests
with transactional callbacks, exercise real committed workers rather than assuming
callback timing from a transactional fixture.

Provider configuration update/disable already releases its connection lock before
RuntimeControl.stop_pending_automation! acquires Conversations; retain that split.
Usage reservation failure must also unwind its accounting transaction before
control cancellation. Authority checks that require a provider/member/origin-record
lock must resolve and acquire it before A/F/D, not discover it inside a publisher.
Read-only status/directory/cockpit consumers of follow-ups are not mutation callers
and need no new domain locks. Destroy/retention work must never be used as a
replacement/retry path and must follow the same order if it touches live artifacts.

### Required concurrency proof for this matrix

In addition to edit/admission races, add real-worker barriers for replace versus
accept, cancel versus accept, recover versus materialize, preparation failure
versus replacement, post-send publication repair versus replacement, and unknown
review creation versus late acceptance. Cover both allowed interleavings. Prove
that an outcome/reconciliation worker cannot be holding D/M/E while waiting for
A/F, that only one current lineage exists, and that a stale queued job never follows
the aggregate pointer to new content. The coordinator accepted this matrix;
implementation and proof remain required before delivery completion.

### Batch lock ordering clarification

Inside one transaction, batch callers prelock all required Attempts in ascending
ID order, then all required artifacts in ascending ID order, then all deliveries,
messages, and outbox records by that same rank and stable ID order. They may
instead use fully separate transactions per aggregate. Iterating
Attempt1 → Artifact1 → Delivery1 → Attempt2 in one transaction is forbidden:
no earlier-ranked lock may be acquired after any later-ranked suffix lock.

### Increment 2 migration rollback and legacy artifact decision

The attempt/lineage migration is irreversible after multiple Offers or successors
exist: restoring the old account/contact/stage uniqueness would discard valid
records or fail. Rollback must use a reviewed forward repair or a complete backup,
never delete history to satisfy the old index. The migration's `down` raises
`ActiveRecord::IrreversibleMigration`. Missing historical context is retained as
empty, with no current Offer or decision inferred. Historical pending records
without admission proof are blocked at the aggregate; this does not manufacture
replacement rights.

Legacy unscoped artifacts are also immutable. A changed legacy question cancels
the old pending artifact with `legacy_question_changed`, consumes that existing
attempt, and schedules no successor. It cannot satisfy the narrow Offer-context
replacement rule. The old scheduler test requiring an in-place rewrite is
explicitly superseded by this history-preserving contract. Unchanged legacy
artifacts retain their existing consent/control and delivery behavior.

### Implementation lock audit refinements

The complete set of current/saved/Result-context Offer IDs is acquired in one
ascending query; two separately sorted queries are insufficient. Existing budget
Attempts likewise lock in one ID-ordered query before create-or-find can implicitly
lock a conflict. Historical row IDs need not follow attempt_number. Actual worker
regressions reproduced both inversions before correction.

Canonical eligibility uses the exact provider/member records acquired before
A/F/D, including an absent record. It never discovers and locks a new authority
row underneath the suffix. Reconnection or membership restoration can authorize
fresh work through a fresh prefix; it cannot add an unowned earlier lock to an
in-flight authorization. Config/day/allowance checks themselves are unchanged.

Historical rows without durable admission/context proof receive a nonreplaceable
blocked aggregate, with original IDs and empty unknown context retained. The
unchanged legacy scheduling/delivery positive controls cover newly scheduled
unscoped work; migration does not manufacture authority for ambiguous old work.
