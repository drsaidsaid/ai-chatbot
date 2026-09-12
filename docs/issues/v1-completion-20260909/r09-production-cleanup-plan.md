# R09 bounded production cleanup plan

The current behavior and public request seams remain the contract. Each group receives its own frozen before/after source trees, reviewed diff, targeted lint and affected checks. Existing accepted-base findings stay separately identified. No lint suppressions or blanket exceptions are introduced.

1. Typed answer and rule helpers: limit changes to `OfferTypedAnswer` and `OfferRules`. Extract the current number/money/boolean/text branches, rule effect validation, compatible operators, normalized comparison values and ordered comparisons into named helpers. Preserve branch order, false versus nil, original return values, exception messages and timing, money parsing and precision, configured-choice comparisons, and evidence polarity checks. Use existing built-in/custom typed-rule and typed-answer request specs, including boundary cases. No persistence, locks, queries or transaction changes.
2. Configuration and evidence writing: separate question validation and persistence steps within current transaction boundaries. Retain configuration conflict check order, all used-field currency/meaning restrictions, and current revision invalidation. Keep the public `field_definition` singleton method public by moving its definition before the instance-private boundary. Never alter existing locked objects or evaluation precedence to satisfy a cop.
3. Qualification evaluation and evidence extraction: extract current observation selection, answer matching, budget assessment and quality branches. Maintain observation ordering and original fact precedence. A Hash-array `pluck` is acceptable only after verifying it is an in-memory array. Database `exists?`/`pluck` replacements require proof that no preloaded or current locked state is discarded.
4. Delivery lifecycle and cancellation: review separately. Materialize the complete existing delivery relation before iterating; never introduce `find_each`, batches or new ordering into the global aggregate lock matrix. Extract early-return logic into a method called inside the same transaction/lock scope only after inspecting the installed ActiveRecord non-local-return semantics and asserting cancellation persists, unavailable attempts send nothing, future deliveries reschedule once, and enqueue remains outside committed writes. Preserve every global lock tier, query ordering and early-exit return.
5. Remaining controller/model/migration formatting and complexity: keep validation error order, callback boundaries, associations and schema results. SQL whitespace changes must be checked for quoted strings and line comments; do not apply squish blindly. Retain distinct accepted baseline findings rather than presenting them as new cleanup.

Before each group, record the exact touched paths and affected check list. The Offer-switch busy-state P2 is a separate JS-only red/green group after the active frozen test cleanup run. No broad build rerun until substantive cleanup groups finish; no normal-hook commit until required reviews and browser acceptance are complete.

## Configuration writer group

Touch only `app/services/ai_lead_employee/offer_configuration_writer.rb`.
Extract the existing persistence statements and question definition/choice checks
without moving them across the Offer transaction, lock, optimistic version check,
used-definition validation, revision creation or stale-marking boundary. Retain
all repeated normalization calls and error precedence. Move the already-public
field-definition class method before the instance-private boundary. Affected
checks: Offer qualification, built-in/custom typed rules, evidence lifecycle and
configuration writer concurrency. Keep the existing stale-marking behavior.

## Delivery and cancellation group

Touch only `app/services/ai_lead_employee/follow_up_delivery_service.rb` and
`app/services/ai_lead_employee/automation_cancellation.rb`. This group precedes
qualification decomposition so the lock-sensitive lint findings remain isolated.
Materialize the existing delivery/message relation before iterating its complete
Offer union; keep the existing ordered Offer lock and A/F/D/M/E lifecycle suffix.
Do not add batching, query reordering or a new authority read. Split the long SQL
literal only at an existing space, preserving the resulting string byte-for-byte.

Extract the current-artifact admission guards, cancellation and materialization
into a method invoked inside the original lifecycle transaction. Keep reason
precedence: opt-out, internal note, incompatible control, Offer context. Return nil
for every former early return, retaining nil/no enqueue on unavailable artifacts,
cancellation and future rescheduling. Enqueue a recorded outbox event only after
the same enclosing transactions finish. Installed ActiveRecord 7.2.3.1
`within_new_transaction` commits in ensure when there is no exception or thread
abort; ordinary method returns and normal block completion therefore retain the
same commit behavior. Existing exceptions retain rollback behavior.

Affected checks: admission races, lifecycle races, terminal invalidation,
follow-up outcomes, lineage, FollowUpDeliveryService and FollowUpScheduler.
Review the complete frozen diff separately from preceding helper groups.

## Validation and Offer-selection controller group

Touch `LeadFollowUp`, `LeadFollowUpAttempt`, `QualificationEvidence`, and the two
Offer controllers only. Extract existing validation clauses and the selection
lookup/lock block into named helpers. Retain the persisted guard, error order,
associated-object reads, immutable-field loop, current-attempt comparisons,
selected-record lookup before locking the full old/new Offer pair, and the
reload/enabled check after locking. The Offer params change is layout only.
No callback, schema, admission, retry or policy behavior changes. Affected checks:
Offer selection authority and policy, evidence edit/lifecycle boundaries,
follow-up lineage/outcomes, and the canonical Offer qualification request path.

## Offer evidence and decision group

Move incoming-message observation recording into OfferEvidenceRecorder, called
only inside the existing Conversation/Offer/Contact locks. Preserve message
eligibility guards, answered-question matching, human/duplicate/newer-fact
precedence, per-observation creation/supersession order, and all current objects.
Extract assessment branches within OfferQualificationService without moving
qualification lookup, timestamps, save, decision creation or result capture.
Array pluck is limited to Offer.questions, an in-memory configured Hash array;
newer-fact exists remains the same fresh database scope and predicate.

Extract normalization and creation helpers in OfferHumanEvidenceWriter, keeping
authorization and C/O/Contact locking unchanged. Give QualificationEvidenceAudit
an instance holding contact/conversation/user/Offer context, then record signal
and value through it. Update its two internal callers, including the legacy
QualificationService path; retain audited fields, value conversion, version
query, timestamp and transaction position exactly. No public HTTP contract or
new observation precedence. Affected checks cover canonical Offer qualification,
typed questions/rules, evidence lifecycle/edit boundaries, human legacy edits,
and writer/evaluator concurrency; legacy human-evidence specs cover the audit
caller. Freeze source and run sequentially within a 20-minute interval.

## Spoken evidence interpretation group

Keep interpretation unchanged while separating budget-tail recognition,
observation value projection and urgency wording into small helpers. Touch the
three existing interpretation files and add QualificationBudgetTail,
QualificationObservation and QualificationUrgencyExtractor. Parent APIs and
context handling stay unchanged. Keep every pattern's exact source/options,
ordered tail anchors, guarded extractor calls, evidence overwrite order,
contextual fallback, polarity/typed-value/basis insertion order, and budget basis
mutation. Split long regex source into adjacent strings without adding regex
flags or changing whitespace. Keep amount parsing and all currency semantics.

Compare complete old/new interpretation pipelines on literal regression cases
and spending/continuation combinations, as supplementary evidence. Run the
existing extraction and budget-continuation specs and Offer request boundary
specs on each frozen candidate; no broad application regression/build.

The spoken group also moves the existing email/phone recognizer into
QualificationContactExtractor to keep the parent extractor bounded. Copy its
patterns and validation order exactly; contextual contact still prefixes the
same text before invoking it. Include contact inputs in old/new comparisons.

## Directory and shared projection group

Extract the two qualification preload assignments into a helper at the same
position before Conversation/booking/follow-up/evidence/consent/message loading.
Preserve the same scopes, cached read-context objects and query order. Move only
evidence-row and follow-up-row Jbuilder field writes into native partials,
passing the existing evidence/context or follow-up objects. Keep relation
queries, authorization, ordering, limits, field names, null behavior and writer
order in the parent. Remove the unused local assignment and use an equivalent
modifier guard for cockpit rendering. Format Account.webhook_data's small hash
on one line; verify full parsed AST equality rather than moving associations.

Affected checks: Offer shared readers and bounded evidence query count,
directory filters, canonical Offer projection, legacy Leads/qualification
controllers and assigned Conversation access. Native Vue and server/build
reruns are unnecessary for this Ruby/Jbuilder-only group. Track resolution of
the accepted Account/Jbuilder lint categories explicitly in final accounting.

## Historical migration group

Touch only migrations 20260911001400, 20260911001500 and 20260911001700.
Extract the unchanged revision-table creation and the attempt table/constraints,
artifact columns, backfill and ownership-finalization phases into private methods
called in the original order. Preserve SQL literals, CASE precedence, joins,
COALESCE, defaults, indexes, constraints and down behavior. Squish only SQL whose
quoted values have no whitespace-sensitive content and no line comments.

Execute the frozen originals and candidates against equivalent isolated schemas
inside rollback transactions. Compare columns/defaults/nullability, indexes,
foreign keys/check constraints and retained/backfilled row values; include signal
0–7 mapping and ambiguous/accepted/admitted/unknown/failed history. Compare the
existing reversible 014 path and the unchanged irreversible 015/017 errors.
Run the existing lineage migration spec and related lineage/canonical Offer
requests. No production database migration or schema dump regeneration.

### Delivery authority, outcome, handoff and consent group

Bounded final production cleanup: extract current-state predicates in OfferDeliveryContext; isolate outbound recovery admission and authorized retry helpers; extract the three ordered locked re-consent withdrawal validations; split handoff lock-body orchestration and move alert recipient resolution to a dedicated collaborator. Keep the same Conversation/Offer/membership and lifecycle lock acquisition order, current reloads, query filters, error precedence, transaction boundaries, recovery booleans, outcome/publication order and post-transaction alert delivery. Preserve the RecordNotUnique rescue scope and existing-handoff retry restrictions. Alert route evaluation and normalization retain their order and deduplication.

Freeze complete before/candidate source trees. Run affected public delivery, race, handoff, consent and Offer-context specs sequentially within the authorized 20-minute group allocation, preserving any live run and reporting abnormal delay. Compare the exact diff and extraction mapping, then full changed-path lint. No retry/admission behavior expansion, new suppressions, broad build/regression, deployment or integration. Root reviews this high-risk group before consolidation.
