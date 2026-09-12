# R09 first-seam review corrections

Status: focused correction verified, 16 examples / 0 failures. Full R09 incomplete.
Original source/evidence remains frozen in tree
`71460ac684fc0aab05aac5e78011e474165f19f8` at
`refs/r09/first-seam-20260911`. The original five tests are unchanged.

## P1: evaluation can lose a configuration invalidation

Hypothesis: the evaluator reads Offer N without a row lock, waits on Contact,
and later saves N with `stale_at: nil`. The writer can commit N+1 and invalidate
existing evaluations during that wait. The stale evaluator then removes the
invalidation. In the reverse ordering, an evaluator can cache N while the writer
holds an uncommitted N+1 and later save N after the writer commits.

Two real worker connections exercise both orderings against committed fixtures.
An observer connection uses a Contact row as a deterministic scheduling gate for
the evaluation-first case; PostgreSQL `pg_blocking_pids` confirms actual row-lock
waits. The writer-first case holds the real configuration writer transaction
open until the evaluator blocks. No lock, persistence, configuration lookup or
service implementation is mocked. Assert both final revision and stale/current
state, not merely that threads finish.

Planned correction: Conversation → Offer (`FOR NO KEY UPDATE`, reload) → Contact
→ Qualification. Retain Offer lock until evidence and evaluation commit. The
writer locks Offer before its atomic revision/invalidation and takes no
Conversation/Contact lock. ADR 0014 documents this order.

Implemented that lock order. Both interleavings reproduced on the original
runtime (8 total examples, 2 failures), then passed after the correction. Source
search confirms OfferConfigurationWriter is the only configuration writer and
`stale_at` invalidator; its transaction performs Offer save, revision insert and
direct Qualification invalidation without Conversation/Contact locks or model
callbacks from the bulk invalidation. Legacy account configuration does not
write Offer configuration. This is not a proof of unrelated legacy lock paths.

## Defense in depth: separate mutation permission from bot-readable access

The original static review hypothesis was that using Conversation `show?` also
allowed a bot to select an Offer. Full request-path verification corrected that
finding: `AccessTokenAuthHelper::BOT_ACCESSIBLE_ENDPOINTS` excludes the new
controller and already denies the real bot HTTP request. There is **no
demonstrated reachable HTTP bot bypass**. All six initial public authority cases
passed, including bot denial, assigned User/administrator success, unassigned
User denial, removed assignment and revoked membership denial. These controls
are preserved; no outer guard is bypassed to manufacture a failure.

A separate policy-contract red establishes the missing mutation-specific
`select_offer?` method. Adding it is defense in depth. Two further real
waiting-request tests revoke membership/assignment while the request is blocked
on the Conversation row; these verify the final check reads current authority.

Planned correction: dedicated User-only Offer-selection policy, with fresh
membership/assignment query under the Conversation lock. Bypass request query
cache for this final mutation authorization. Do not modify R07 control/status
methods or broaden bot capabilities.

## Verification boundary

Run these focused tests red before runtime edits, then green alongside the
original five cases. No build/browser/live provider calls. Record exact source
hashes, raw outputs and service release. Broader typed-field/rule/evidence tests
prepared in `r09-second-slice-semantics.md` remain behind these P1 corrections.

Observed results: original concurrency/HTTP set 8 examples / 2 concurrency
failures; missing mutation-policy contract 1 example / 1 failure; existing
waiting-request revocation controls 2 examples / 0 failures before the defense
change; combined corrected concurrency, policy, public authority and original
first-seam set 16 examples / 0 failures. No original assertions were weakened.
Raw outputs and immutable source identity are preserved under
`docs/releases/2026-09-11-r09-review-corrections/`.
