# R09 delivery RED-only evidence and proposed lock matrix

This is observed RED evidence on unchanged frozen reader runtime
`bd6e54aae5a7e6d2b3405d29528e63488879380d`, not a delivery implementation or green
claim. The retained tree ref is `refs/r09/delivery-red-lock-matrix-20260911`.
Its external frozen-tree.json sidecar is written after freezing, not inside its
own tree. Earlier source/evidence refs and directories remain unchanged.

## Observed run

The previously prepared offer_delivery_revision_spec ran on the dedicated test
database: **9 examples, 7 failures**. The seven failures were missing qualification
context in the OutboxEvent; failure to cancel a reply after Offer configuration,
selection or same-revision human evidence changed; reuse of one follow-up attempt
across two Offers; preparation of a stale follow-up; and creation of a handoff
from an invalidated Highly Qualified result.

Two controls passed: editing an unrelated Offer still reached provider acceptance
exactly once across repeated jobs; disabling the provider still canceled delivery.
All HTTP was stubbed and no AI provider extraction was called. No live WhatsApp
or model send occurred. The failed cancellation examples stop at their state
assertions; this report does not invent per-failure HTTP request counts.

Raw log: evidence/offer-delivery-context-red.txt. The executed specification was
not changed from the version in frozenbd6e54. All54 reader-manifest source paths
plus the delivery spec (55 total) were independently compared to that exact ref
and are unchanged. No production/schema/test edits were made in this allocation.

## Source-only proposal

ADR0015 remains proposed. Its expanded caller matrix requires Attempt → Artifact
→ Delivery → Message → Outbox for every path touching those records. Publication
becomes projection-only; mark_follow_up_sent/aggregate transitions move to an
owner operation with earlier locks already held. The matrix covers preparation,
materialization, replacement, final authorization, greeting deferral, accept,
definite failure, unknown, lease recovery, preparation failure, post-send repair,
operator retry, direct and callback cancellation, provider invalidation and
provider-status callbacks. It prelocks required owned Conversations/Offers and
review/domain authority before the shared suffix, and never acquires earlier
locks while holding a later Delivery/Message/Outbox lock.

Accept/unknown prelock their local review Conversation and existing review rows
before Attempt/Artifact/Delivery to preserve idempotent unknown-review creation
and late acceptance resolution. Other outcome paths need no new Channel/Offer
locks. Claim-only stays Delivery-only with no publication/domain work. The Offer
config writer never acquires Conversations. Stable owned Conversation order,
unknown-acceptance no-retry and maximum attempts remain requirements.

Private R04 patch59a3bbf is not accepted/integrated9a and does not fix
FollowUpDeliveryService; it concerns LeadUpdateService and three IntentProcessor
non-key locks. No private ancestry was imported. The exact matrix and immutable
replacement/index design require coordinator acceptance before any migration or
delivery implementation.

The RED-only heavy interval is complete. Dedicated PostgreSQL55519 and Redis6421
were stopped successfully and listener checks are empty. No build, browser,
hooks, commit or deployment occurred. Full R09 remains incomplete.
