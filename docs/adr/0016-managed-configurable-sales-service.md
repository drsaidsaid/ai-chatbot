---
status: accepted
date: 2026-09-12
supersedes: selected product-scope and provider-ownership clauses in 0002 and 0007
---

# Deliver a configurable managed WhatsApp sales service

The owner confirmed the product decisions through a grilling interview and authorised tickets and resumed implementation. The normative product contract is [Product agreement](../v1-alignment-2026-09-12/PRODUCT_AGREEMENT.md).

## Decision

Business-specific documents can propose versioned Offer knowledge, prices, qualification and next steps, but only explicit publication activates interpreted instructions. Qualification is optional; absent criteria never trigger hardcoded defaults. Commercial facts have one authoritative published Offer record. Sales eligibility and basic human help are separate. Paid consultation is one optional Offer type, not global product behavior.

Provider ownership becomes platform-operated. Business Account admins cannot configure or access provider secrets/model routes; account-isolated usage and charges remain. Preserve encrypted storage, durable provider admission and canonical delivery; an implementation slice must supply an explicit migration and rollback path before changing deployed credential authority. Existing R10 does not itself implement this new ownership.

Manual verified payments activate monthly plans, carried-forward top-ups or plan upgrades through a durable idempotent entitlement boundary. Reserve before AI work and settle one billable logical reply at confirmed canonical send; internal work and retry count are not client charges. Costs and customer charges are separate ledgers. Unknown provider costs cannot become zero. Meta billing remains separate and clearly labelled.

Inbound ad-set mapping (including future ads), template management and bounded consented broadcasts are now approved V1 scope. This supersedes their earlier blanket deferral. Paid API execution still requires bounded concrete authorisation. Broad ad management, additional channels, autonomous marketing and WhatsApp Status publishing remain out of scope.

## Preserved boundaries

Owned Community Edition Rails/Vue, MIT, no enterprise code, tenant isolation, consent, explicit human control, immutable evidence and canonical outbound delivery remain mandatory. Do not weaken R09's reviewed Offer context or delivery-attempt lineage. Draft ADR numbers 0014/0015 in the R09 candidate are reserved and not replaced by this decision.

## Consequences

R01–R18 are not the full launch scope anymore. Follow the dependency plan R19–R28 and amended launch gates. A plain-language setup replaces contradictory fixed sales-interview assumptions. Provider/finance platform permissions must be distinct from Business Account admin permission. Exact tariff amounts, current OPU price and final brand are not inferred from examples.
