# R09 implementation decision and verification plan

Date: 2026-09-11. Source baseline: `9a834e756347822d4ae5af15f268a5e8751fc852`.
Status: first bounded API/inbound slice verified; full implementation in progress.
The heavy interval is released. No build/browser allocation yet.
This is a bounded implementation of published R09, not evidence of acceptance.

First observed red: five public request/inbound examples failed on the accepted
baseline because the Offer route returned 404. The same unchanged examples then
passed (5 examples, 0 failures) after implementation and migration. See the
[first-slice evidence](../../releases/2026-09-11-r09-first-seam/README.md) for raw
logs and source hashes. Isolated PostgreSQL55519/Redis6421 were stopped after
green and the heavy interval was explicitly released to the coordinator.

The initial source slice implements Offer configuration, explicit selection and
built-in incoming evidence. Rule editing, custom typed answer interpretation,
complete history replay, revision dispatch fences and Vue presentation are
subsequent red/green work; the preparation branch is not a release candidate.

## Decision

Use the existing owned Rails/Vue settings and inbox. Activate the retained
`ai_lead_employee_offers` table instead of introducing a second Offer store.
Each Offer owns its question definitions, budget ranges, deterministic rules,
score thresholds, and monotonically increasing configuration revision.
The Business Account continues to own follow-up and provider settings separately.

A Conversation records the Offer currently being discussed. Automatically select
only a sole enabled Offer; with multiple enabled Offers and no selection, ask
which Offer the Lead wants before asking purchase questions. An authorized
operator may explicitly change the selection. Do not infer Offer eligibility
from campaign, referral, income, or lead-volume keywords. Campaign routing and a
general conditional conversation builder remain outside R09.

Question identity and meaning are separate from editable wording and order.
Retain built-in meanings for name, business type, problem, inquiry volume,
urgency, purchasing budget, authority and contact details. Add distinct typed
fields rather than relabeling an inquiry count as revenue. V1 custom fields use
text, boolean, number, money or a bounded choice list, with an explicit meaning
and optional unit/period. Once evidence references a field, changing its type,
meaning, currency or period requires a new field key; archiving keeps its history.
Custom answers bind only to the verified preceding question in that Conversation;
an arbitrary number or an unrelated response cannot populate a custom field.
Explicit built-in facts may answer several fields from one incoming message.

Store one current Qualification per Business Account, Lead and Offer. Keep
historical decisions and their configuration/evidence snapshots. Name and contact
identity remain shared Lead facts; Offer-specific purchasing facts never migrate
to another Offer because the same person participates in both Conversations.
Evidence records stable field identity, Offer, polarity, normalized typed value,
observation time and source message or human edit. Corrections supersede earlier
evidence without deleting it. No unknown or negative observation earns a score
merely because its field exists.

Use a bounded rule interpreter: presence/positive/negative, typed equality and
choice membership, and numeric/money comparisons. Reject incompatible operators,
unknown fields, mixed-currency comparisons and malformed values on save. Rules
can add nonnegative score weights or force Unqualified; they cannot execute code
or override the PRD's buying-evidence and handoff requirements. Highly Qualified
requires supported pain, urgency, sufficient purchasing budget and authority.
An explicit absence of business/relevant professional activity is Unqualified;
unknown business activity is missing information, not an automatic rejection.
An Offer may require additional evidence and set its scoring thresholds. Every
enabled requirement is evaluated; rules sharing one field form an order-independent
conjunction rather than overwriting one another.

For an Offer whose next step is a sales call, automatic assignment requires
every current configured fit, readiness and action-eligibility requirement to be
met, no hard-rule exclusion, and explicit positive boolean evidence for the
stable `sales_call_agreement` field. A dimension is canonically `not_required`
only when the current Offer has no enabled requirement or enabled required
question for it; that state is admissible without manufacturing a requirement.
Absent, inconsistent or malformed assessment data fails closed. The agreement
field is an owner-configurable question, not a global script; no fixed budget,
urgency, authority or answer count is restored. Basic human assistance remains
a separate R14 route and does not authorize a sales call.

Currency inputs and API output use labeled major-unit decimal strings. Convert
exactly at the persistence boundary to integer minor units; never use floating
point arithmetic or treat a database minor-unit value as the displayed amount.
Revenue, income, available money and committed purchasing budget remain distinct.
No exchange-rate conversion or silent USD/TZS substitution is allowed.

Save each Offer's configuration atomically with optimistic revision checking.
An edit invalidates its current evaluations and queued qualification-dependent
actions. It does not erase original observations, alter consent, invalidate
another Offer, or silently reinterpret existing field meaning. Re-evaluation
uses current configuration and compatible current evidence. A stale result is
visibly stale and cannot authorize a new handoff, follow-up or outbound message.
Dispatch rechecks the Offer/revision alongside existing R10 provider, allowance,
consent, membership and Conversation control fences.

Lead views expose an explicit list/selection of Offer evaluations; Conversation
views show the selected Offer. Both display quality, reasons, missing evidence,
source references, freshness and next action. ADR 0010 still restricts members
to assigned Conversations; shared Lead identity never exposes a combined
evaluation derived from inaccessible Conversations.

## Migration and overlap boundaries

- Backfill legacy account-level configuration into an explicitly labeled legacy
  Offer only when its mapping is unambiguous. Preserve legacy evidence and
  decisions; never fan their buying facts out across multiple Offers. Mark
  unassigned historical evaluations as legacy rather than presenting them as a
  new Offer's qualification. Backfill must be repeatable and account-isolated.
- Reuse reviewed generic repair source deliberately through `111345d`, never
  private pilot ancestry. Retain the original `can spend $2500` Highly Qualified
  regression unchanged. The coordinator clarified the approved PRD meaning:
  explicit purchase spending capacity is positive budget evidence, without
  claiming payment or committed funds. Offer rules determine sufficiency. Add
  contrasting income, unrelated spending, conditional funding, negation and
  currency cases; do not alter the retained input or expected outcome.
- Preserve accepted R10 IntentProcessor/provider/allowance fences. Coordinate
  any narrow processor, dispatch, R07 control or R04 locking changes before
  editing those shared boundaries. Use the current tree, not an old processor.
- The coordinator reserved ADR 0014 for this decision.

## First meaningful red tests

1. Through the administrator HTTP API, save Offer A with a TZS `500000.00`
   minimum and ordered questions. Reload and save unchanged: the amount stays
   `500000.00`, its currency stays TZS, and the stored amount is exact. Save a
   distinct Offer B configuration. A member and an administrator from another
   Business Account cannot change either Offer.
2. Feed a supported incoming message through the existing orchestration job for
   an explicitly selected Offer A. Assert the persisted evaluation's Offer,
   matching configuration revision and source message; verify the outgoing
   message asks exactly one unanswered Offer A question. For the same Lead on
   Offer B, assert no inherited A budget, score or question order.
3. Change A's threshold after generation but before final delivery. Assert its
   previous result is stale and the queued reply cannot be dispatched; B remains
   current. Re-evaluation uses A's new threshold without erasing evidence.

Subsequent behavioral cases cover explicit English/Swahili/TZS positives,
negation, uncertainty, later corrections, human evidence precedence, revenue
versus purchasing budget, verified contextual custom answers, ambiguous Offer
selection, changed field meaning, question ordering/non-repetition, missing
signals, archived Offers, concurrent configuration edits, member reassignment,
and existing provider/consent/takeover fences. Preserve retained regressions.

## Execution and evidence

The first allocated Rails interval is complete and released. The five public
path examples have observed red/green evidence; prepared capacity/allocation
contrasts remain unexecuted. Subsequent slices require a new coordinated test
interval. Continue in behavior-sized red/green increments, then run required
lint/build and in-app browser validation when allocated. No broad build, hooks,
browser validation, live provider/WhatsApp sends or deployment occurred in this
first interval.
