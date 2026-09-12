# R09 first delivery increment

Status: allocated; ADR0015 accepted after complete reader e7601952 review.

Implement monotonically versioned Offer selection, exact decision context in the
qualification Result, persisted Message/event context, canonical reply admission
fences and handoff assignment/queued alert fences. Preserve unrelated-Offer and
legacy controls, provider/configuration/day/allowance, consent/control, unknown
and once-only outcomes. Add real independent-worker edit-first/admission-first
races, A→B→A, same-config correction and queued handoff alert cases.

Run prepared normal-reply/handoff cases and new cases red before implementation.
The two prepared follow-up cases remain known failures owned by increment two.
Do not report the entire prepared9 suite green. Freeze complete source and actual
evidence for review before any logical-attempt schema or lifecycle expansion.

Blockers for increment two: first increment reviewed; then add logical-attempt
schema, immutable replacement and every publication/outcome/recovery/cancellation
caller from ADR0015. Vue/R07 controls/deployment remain unallocated.

## Implemented candidate and remaining boundary

Initial proof16/14 plus independent-worker4/3; first implementation20/0.
Additional context mismatch3/1 was fixed by pairing the supplied Qualification
with the frozen qualification/Offer ids. Legacy handoff compatibility10/8 exposed
Conversation display-id reload handling and duplicate-create rescue; both repaired
without changing legacy expectations. Expanded Offer checks25/0 and subsequent
Offer+legacy handoff checks28/0 are observed before final compatibility.

The migration adds only Conversation.offer_selection_version, preserving zero
for historical selection provenance. A save callback advances real Offer changes;
explicit and automatic writers hold Conversation/Offer locks. Evaluation captures
the exact newly recorded decision in Result and copies it to Message/event and
handoff snapshot/alert. Canonical admission owns Conversation/Offer plus required
provider/member/alert authority before Delivery. HTTP stays outside those locks.

Increment two remains unimplemented: logical Attempt table and immutable artifact
lineage, per-Offer attempt budgets, narrow context-only replacement, scheduler and
materializer ordering, atomic Attempt admission, projection-only publication,
ordered accept/fail/unknown/recover/preparation failure/repair/retry/cancellation
entry points, rank-batched locking across all model/callback/consent/control/provider
callers, and associated concurrency evidence. Those paths retain their preexisting
implementation in this increment; this is not a claim the whole matrix is fulfilled.
The two prepared follow-up examples are excluded from first-increment success.
