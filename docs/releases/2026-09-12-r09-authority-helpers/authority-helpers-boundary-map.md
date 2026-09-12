# Authority cleanup boundary mapping

## Outbound recovery and retry

`recover!` still enters `with_lifecycle(review: true)` before inspecting current delivery state. The helper calls `admission_failure` only when pending or claimed, then calls `cancel!` with the same truthy reason and returns true explicitly; the caller uses `next false`. A false/nil reason continues through the original pending timestamp update, future lease guard, dispatching-to-unknown outcome, or claimed recovery branch. No cancellation return value changes the public result. `record_unknown_locked!` changes only adjacent string formatting; its final message text and review creation/publication order are identical.

`retry_for?` retains its outer transaction, Conversation lock and reload, Offer locks, then membership lock followed by account reload and role/assignment check. The membership query and short-circuit predicate moved together into `retry_authorized?`. Only then does the original `with_lifecycle` run. `retry_locked!` has the same artifact guard, failed/current message-source guard, delivery update, message update, publication and true result. Its local `return false` becomes the block's value; it does not return from the caller or transaction. Exceptions still propagate through both transaction wrappers.

## Consent

`grant!` retains trusted-source and administrator checks before its transaction. Inside: channel lock → ordered Conversation locks → cancellation Offer locks → locked current opt-out lookup. The three raises are extracted together, in the same absence/version/time order. Event creation, opt-out destruction, version invalidation/cancellation and Result construction remain in the transaction. The helper returns no state used by the caller.

## Handoff

`perform` retains the Conversation reload/lock around each normal and RecordNotUnique recovery branch. The rescue still covers the same full perform body, including alert delivery. `perform_handoff_locked` does the original existing-handoff read, saved-vs-new context selection, authority construction and Offer lock before any branch. Existing retry restrictions remain in that branch. `create_handoff_result` checks context match, authority failure, qualification reload and automatic handoff eligibility in their original order, followed by create/assignment/Result. The duplicate recovery branch preserves its lookup, authority lock and retry checks.

Extracted local `return Result.new` returns to the lock block, which completes normally exactly like its former `next Result.new`; no transaction is exited nonlocally. `deliver_result_alerts` remains after the lock block returns. Recipient resolution retains route iteration, administrator evaluation, phone lookup, normalization, flattening, filtering and deduplication order in HandoffAlertRecipients. Its only initialized inputs are the same Account and constant alert type.

## Offer context

`failure_code` still checks empty context → identity → selected Offer/version → query Offer → enabled/config version → query scoped qualification → stale/config version → query latest decision → decision ID and Offer/account/contact identity. Extracted predicates contain the same short-circuit expressions and the latest-decision query remains after the qualification check. There are no caches, replacement contexts, extra locks or new query scopes. All prior failure strings and their precedence are preserved.

## Evidence limits

The parsed-body proof reconstructs consent, complete retry and handoff transaction/rescue bodies and compares five moved recipient methods. Recovery guard equivalence and context predicate order are supported by this explicit mapping, the exact diff and existing public/race regression cases. This is not a claim that all Ruby semantics are proven by syntax comparison, nor a substitute for root high-risk review.
