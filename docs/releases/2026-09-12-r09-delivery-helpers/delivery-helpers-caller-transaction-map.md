# Delivery/cancellation caller and transaction mapping

Before production source: a5253e37a45f46e99e6af3e92139c2282f18a722.
Prepared extraction: b05b93a1209c4f3f505f8a749753fff21bfc6cd5.
Original implementation plus complete eight-example characterization baseline:
78e8ce9a4d01de68e5b292aff2c7308f79382f58. Formatting-only changes to the new
spec occur before the final candidate freeze; each run retains its actual tree.

| Stage | Before | After | Preserved boundary |
|---|---|---|---|
| Entry | `perform` initializes nil event id, then reloads and locks Conversation | `perform` assigns the result of the same reload/lock block | Same Conversation object access and `FOR NO KEY UPDATE` transaction |
| Authority | Construct OfferDeliveryContext and call `lock_offers!` | Same statements before entering lifecycle owner | Same Offer prefix and context capture |
| Ownership | `DeliveryLifecycle.with` materializes and locks A/F/D/M/E suffix | Same call and relation | No lock query, lock order or owner implementation change |
| Current artifact | Replace `@follow_up` with owner row, then check pending/current and replaceability | Same sequence in `materialize_current_follow_up!`, invoked inside owner block | Same loaded/locked rows and short-circuit order |
| Failure reason | opt-out → internal note → incompatible control → context failure | Same order in `cancellation_reason` | No extra authority query or reason precedence change |
| Cancellation | Owner cancellation, then method-wide nil return through both transaction ensures | Same owner cancellation, helper returns nil, both transaction blocks finish normally | Attempt/artifact/delivery publication remains inside same transaction; outer job not enqueued |
| Materialization | `record_follow_up!` returns event id or reschedules and returns nil | Same method call in same owner transaction | Same writes, rescheduling and return payload |
| External job | Enqueue OutboxDispatchJob after enclosing transaction blocks, only for present event id | Same final call and present check | Eight-example committed suite observes real rows from another connection at enqueue time |
| Exception | Error propagates through lifecycle and Conversation transactions | Same propagation | Real outbox CHECK violation verifies Message/artifact writes roll back and no dispatch is queued |
| Offer union | Delivery relation with Message include loads all records through relation iteration | Explicit `.to_a` before iteration | Complete original relation, no batches; ordered Offer lock and all later lifecycle locks unchanged |
| Cancellation SQL | One string literal | Adjacent string literals at an existing space | Parsed SQL literal is byte-identical |

Installed ActiveRecord 7.2.3.1 `within_new_transaction` commits from ensure if
there is no rescued exception and the thread is not aborting. `with_lock` yields
inside its transaction; DeliveryLifecycle.with has no side effects after yield.
This implementation reading supports the mapping; it is not the sole evidence.
The baseline and candidate suites assert committed cancellation/Attempt state,
unchanged early-exit records, future rescheduling, actual exception rollback and
publication visibility. Existing admission/lifecycle worker interleavings,
terminal invalidation, lineage and canonical outcomes run alongside them.

No retry/admission semantics or production transaction configuration changed.
