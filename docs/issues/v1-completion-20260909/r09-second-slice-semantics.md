# R09 next slice: typed facts and deterministic Offer rules

Status: capacity/allocation and adversative continuation corrections verified.
Typed/rule and lifecycle cases have now executed; see the latest evidence-lifecycle release. Services are retained under
the coordinator allocation for the next semantic slice; continuation evidence
is in docs/releases/2026-09-11-r09-capacity-continuations/README.md. See `docs/releases/2026-09-11-r09-purchase-capacity/README.md` for
14 capacity/original-HQ/Offer tests, 6 financial HTTP contrasts, and 16 repeated
first-seam/concurrency/authority checks, all passing on the final source.
No hooks, build or browser work ran. The first five-example seam remains frozen as tree
`71460ac684fc0aab05aac5e78011e474165f19f8`, retained by
`refs/r09/first-seam-20260911`; its source and raw red/green logs are retrievable.

## Semantic contract

Budget evidence retains a basis as well as polarity and amount: `capacity`
means the Lead explicitly says they can spend on the contemplated purchase;
`allocation` means they explicitly set funds aside; `stated_budget` covers a
declared budget or a direct answer to the verified budget question. None proves
payment. Unknown or negative budget observations do not acquire a positive basis
or score. Existing legacy observations without a basis are not relabeled as
allocations. Snapshot and human-edit serialization must retain this distinction.

The original `I need more leads now. I am the owner of the agency and can spend
$2500.` job regression stays unchanged. Positive capacity can satisfy an Offer's
budget sufficiency rule. Income/revenue, unrelated spending, funding conditional
on approval, negation and unknown currency cannot substitute for that evidence.
Clauses and corrections preserve the latest asserted meaning without dropping a
later condition. Swahili evidence uses the same semantics and exact money parser.

Custom fields retain stable keys, explicit meanings and answer types (`text`,
`boolean`, `number`, `money`, `choice`). A numeric count cannot become revenue by
editing its prompt or answer type. A money field uses the Offer currency and a
declared period where relevant. Bare numbers and amounts bind only to the actual
immediately preceding public outgoing question in the same Conversation, with
matching Offer, field key and configuration revision. Explicit facts about a
different signal take precedence and never also populate the custom field.
Questions, acknowledgements and unrelated facts do not become text answers.
Custom money answers require an unambiguous amount/currency; custom number
answers require a complete numeric answer; choices use their configured values.
No model call is needed for these bounded typed answers.

Persist a stable `field_key` on evidence, retaining the legacy enum mapping for
built-in fields. Preserve existing evidence IDs, values, sources, Offer scope and
supersession chains during migration. Custom fields must not be forced into the
legacy enum. Once evidence uses a field, its key/meaning/type/currency/period and
choice meanings cannot be silently changed or reintroduced differently after
archiving. Prompt/order/enabled/required changes remain configuration edits;
changing semantics requires a new field key. Historical revision snapshots
remain immutable.

Rules have `kind`, `field`, `operator`, typed `value`, priority and enabled state.
`score_rule` adds a nonnegative `score_delta`; `hard_rule` can force
`unqualified`. Allowed operators are explicit polarity (`positive`, `negative`),
known evidence (`known`), typed equality (`eq`), choice membership (`in`) and
ordered numeric/money comparisons (`lt`, `lte`, `gt`, `gte`). Missing/unknown
evidence never matches a numeric or equality rule. Money comparison values cross
the API as labeled major units and use the same exact conversion as ranges.
Unknown fields, incompatible operators, unsupported precision/currency, negative
weights and arbitrary forced quality upgrades are rejected atomically.

Per-Offer `score_weights` allow administrators to configure the contribution of
positive built-in/custom facts; existing built-in defaults apply when omitted,
and custom fields default to zero. Enabled matching score rules add their stated
delta. Weights and deltas are nonnegative integers; score is a total, not a
percentage. Qualified/Highly Qualified thresholds are nonnegative integers with
the Highly Qualified threshold at least the Qualified threshold. Numeric score
never bypasses the PRD's supported pain, urgency, sufficient budget and authority
requirements, required Offer fields, or hard exclusions. Reasons identify each
applied rule and its supporting source. Unknown/negative/insufficient evidence
can remain a missing qualification requirement without being asked repeatedly.

Corrections supersede only the same field of the same Offer for that Lead. Older
message replay cannot resurrect a superseded amount. Human corrections include
explicit Conversation and Offer context, source user and polarity, and retain
their precedence over subsequent automatic extraction. The controller must not
choose an unrelated "latest Conversation" to interpret the edit.

On a configuration edit, mark only that Offer's existing evaluations stale and
retain original observations/decisions. Reevaluate using the new revision and
compatible evidence; a threshold change does not erase an observed budget. An
answer to an obsolete question revision is not interpreted under the new field
configuration. A saved all-disabled or empty question list remains empty.

## Next tests and order

After the verified capacity sub-slice, begin the next allocated interval with the
custom revenue/actual preceding-question case, typed answer cases and saved
numeric rule cases in `offer_typed_field_rules_spec.rb`. Their prepared controls
also cover per-Offer custom-fact/rule isolation, inquiry-key/revenue mismatch,
unknown fields, incompatible operators, malformed numbers, negative weights,
forced quality upgrades, cross-currency rule values and atomic save rejection.
Do not count these prepared examples as observed red or green until executed.

1. Run the prepared pure capacity/allocation contrasts. Then run the original
   unchanged Highly Qualified orchestration regression, plus an Offer-specific
   capacity case and actual income/conditional/negative contrasts. Preserve red
   outputs; implement the minimal normalization/snapshot correction.
2. Exercise actual public Offer settings and actual outgoing question/incoming
   answer jobs for number, money, boolean and choice fields. Prove a revenue
   answer does not fill budget or inquiry volume, a budget correction does not
   also fill revenue, and another Conversation or stale question cannot bind it.
3. Save typed hard/score rules via HTTP and observe their effect on the next
   incoming message's score, quality, missing fields and reason. Reject invalid
   operator/type, mixed currency, malformed numeric and attempted forced-upgrade
   rules without partially changing configuration.
4. Exercise positive/negative/unknown/corrected evidence on one Offer alongside
   an independent evaluation of the same Lead on another Offer. Replay the older
   source and retain the corrected result/provenance. Cover a scoped human edit.
5. Change an Offer threshold after evaluation, observe only its stale result,
   then reevaluate from retained evidence at the new revision. Keep the other
   Offer's result current. Reject field redefinition after evidence and preserve
   historical configuration snapshots.

## Still separate completion work

Final outbound/handoff/follow-up authorization must fence Offer selection and
configuration revision changes. This requires real delayed/concurrent dispatch
tests and narrow compatibility edits preserving R10 provider/day/terminal-failure
checks and any separately accepted R04 lock clauses. Marking `stale_at` alone
does not prove that boundary. Root owns allocation and integration of those
shared changes.

Shared Lead/Conversation readers, current membership/assignment restrictions,
source-linked human-edit UI, and the complete Vue settings/Lead/Conversation path
remain tracked R09 work. The first seam's singular `contact.lead_qualification`
callers are not a completed per-Offer presentation. No campaign/referral routing,
conditional workflow builder or Online Profits business rules belong in this slice.

## Observed next-slice evidence (in progress)

Typed settings/answers/rules first red: 19 examples, 17 failures; initial
correction 19/0. Added answer/rule boundaries: 14 examples, 4 failures
(conditional money, qualified score bypass and choice-list input loss).
Corrected combined suite: 33 examples, 0 failures.

Evidence lifecycle observed 13 examples, 2 failures: explicit human-edit
Offer/Conversation context and stable field semantics after use. No lifecycle
correction has been made yet. Root requested a second adversative capacity
correction first; new English/Swahili ambiguity cases are executing.

## Lifecycle and reviewed-rule result

Latest retained proof: docs/releases/2026-09-11-r09-evidence-lifecycle/README.md.
Initial lifecycle13/2 is corrected; human/edit/archive/currency plus R06 checks
passed28/0. Review regressions for dependent financial facts and built-in typed
rules reproduced17/12, then focused69/0. Final cross-slice compatibility91/0.
General readers, Vue and final delivery revision fences remain incomplete.
Services are released after this result for coordinator review.
