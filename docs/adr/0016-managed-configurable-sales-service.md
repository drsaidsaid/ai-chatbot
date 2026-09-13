---
status: accepted
date: 2026-09-12
supersedes: selected product-scope and provider-ownership clauses in 0002 and 0007
---

# Deliver a configurable managed WhatsApp sales service

The owner confirmed the product decisions through a grilling interview and authorised tickets and resumed implementation. The normative product contract is [Product agreement](../v1-alignment-2026-09-12/PRODUCT_AGREEMENT.md).

## Decision

Business-specific documents can propose versioned Offer knowledge, prices, qualification and next steps, but only explicit publication activates interpreted instructions. Qualification is optional; absent criteria never trigger hardcoded defaults. Commercial facts have one authoritative published Offer record. Sales eligibility and basic human help are separate. Paid consultation is one optional Offer type, not global product behavior.

Automated sales-call handoff requires every current configured fit, readiness and action-eligibility requirement to be met, no hard-rule exclusion, and explicit positive boolean evidence under the Offer field `sales_call_agreement`. A canonical `not_required` dimension is valid only when the current Offer has no enabled requirement or enabled required question for that dimension; absent or damaged assessment data cannot authorize assignment. The stable agreement field is available to owners as a configurable boolean question; it does not introduce universal budget, urgency, authority or answer-count requirements. Basic human assistance remains a separate route.

Provider ownership becomes platform-operated. Business Account admins cannot configure or access provider secrets/model routes; account-isolated usage and charges remain. Preserve encrypted storage, durable provider admission and canonical delivery; an implementation slice must supply an explicit migration and rollback path before changing deployed credential authority. Existing R10 does not itself implement this new ownership.

Manual verified payments activate monthly plans, carried-forward top-ups or plan upgrades through a durable idempotent entitlement boundary. Reserve before AI work and settle one billable logical reply at confirmed canonical send; internal work and retry count are not client charges. Costs and customer charges are separate ledgers. Unknown provider costs cannot become zero. Meta billing remains separate and clearly labelled.

A split reply with both confirmed-sent and failed parts is recorded as `partially_delivered` while reconciliation is pending: it is not billed, its credit remains held, and it cannot be resent automatically. An authorised Platform Operator may close a proven terminal partial failure as `partial_failure_closed`; closure releases the customer credit exactly once while permanently blocking retry of the closed logical reply and preserving canonical sent evidence and provider cost records. A new inbound logical reply may reserve the newly available credit normally, but closure never re-dispatches the old reply. Settlement time is the latest canonical receipt time, falling back to reconciliation time only when the provider supplies no timestamp. The payment entitlement service itself locks and rechecks the current Platform Operator finance authority; controller authorization alone is not sufficient.

Inbound ad-set mapping (including future ads), template management and bounded consented broadcasts are now approved V1 scope. This supersedes their earlier blanket deferral. Paid API execution still requires bounded concrete authorisation. Broad ad management, additional channels, autonomous marketing and WhatsApp Status publishing remain out of scope.

## Preserved boundaries

Owned Community Edition Rails/Vue, MIT, no enterprise code, tenant isolation, consent, explicit human control, immutable evidence and canonical outbound delivery remain mandatory. Do not weaken R09's reviewed Offer context or delivery-attempt lineage. Draft ADR numbers 0014/0015 in the R09 candidate are reserved and not replaced by this decision.

## Consequences

R01–R18 are not the full launch scope anymore. Follow the dependency plan R19–R28 and amended launch gates. A plain-language setup replaces contradictory fixed sales-interview assumptions. Provider/finance platform permissions must be distinct from Business Account admin permission. Exact tariff amounts, current OPU price and final brand are not inferred from examples.


### Combined qualification and billing delivery authority

R23 integration retains the accepted R09 authorization prefix and delivery lifecycle.
Manual finance reconciliation takes Account, current PlatformApp, Subscription,
Usage, Subscription Alerts, then all linked Deliveries and Messages in stable ID order. Both partial
closure and confirmed-not-sent release evaluate canonical evidence under those
locks. A receipt transaction releases its Message lock before reconciling Usage.
Charged operator retries take their Conversation/Offer/membership authority prefix,
then Subscription, Usage and Subscription Alerts before entering the Attempt/Artifact/Delivery/Message/
Outbox lifecycle; reservation changes happen only after lifecycle eligibility.
Subscription alert retries run outside the alert delivery service's alert lock,
acquire Conversation before alert authority, and enforce the retry ceiling inside
the transition. Replayed jobs cannot bypass it.

Integration renumbers the four not-yet-integrated R23 migrations to
20260912000600, 20260912000700, 20260912000800 and 20260912000900, preserving their
contents and order. Accepted R09 already owns 20260912000100; R26 retains
20260912000400. Candidate evidence retains its historical migration filenames;
combined acceptance uses the renamed sequence. No deployed migration is renamed.
