# R09 shared reader response contract

Coordinator decision: explicit `offer_id` governs qualification/filter/sort/count.
When Offers exist and no Offer is selected, return a neutral, labeled selection
state and selectable Offer summaries. Never select the highest/latest/sole Offer
implicitly in a reader. Legacy unscoped history remains separate. Preserve R06
`complete_contact_ids` and existing Conversation control/cockpit/event behavior.
This contract is documented before shared-reader implementation.

## Additive response fields

The existing flat `GET lead_qualifications/:contact_id` response keeps its current
keys. Add `offer_id` (selected id or null), `selection_required` (boolean),
`offers` (account-scoped summary list), `current_configuration_version` (selected
Offer's current revision or null), and `legacy_qualification` (separate labeled
history or null). Existing `configuration_version` is the evaluated revision,
null for an unevaluated/neutral result; `stale_at` remains explicit. Each Offer
summary is `{id, name, currency, enabled, configuration_version}`. Disabled Offers
can be viewed historically but the enabled flag prevents treating them as selectable
for new work. A cross-account/nonexistent requested Offer returns404.

When selection is required, current `quality` is unknown, `score` is0, `reasons`,
`missing_signals` and `evidence_records` are empty, `evidence` is empty, and
`next_question` is null. Historical quality must not fill these current fields.
`legacy_qualification`, when visible, has `scope: legacy_unscoped`, a human label,
quality, score, reasons, original structured evidence, evaluated configuration
version and evaluation time. This is preserved history, not a current Offer result.
Accounts without any Offers keep their existing legacy qualification behavior,
with additive context fields indicating no selection is required.

`GET leads` retains `leads`, `selected_lead`, `counts`, `filter_options`, `meta`.
Add the same selection fields at the envelope and row level so `GET leads/:id`
(the existing row response) is self-contained. Existing row quality/score and
`detail.qualification` use the explicit Offer. The detail qualification gains
Offer/current/evaluated revision/stale/selection fields. `detail.legacy_qualification`
contains separately labeled visible legacy history. Evidence details preserve
normalized values, basis and source links rather than losing everything except
the display string. Existing identity/contact/consent fields remain compatible.

Without selection, qualification-based quality/follow-up/booking filters and quality/score
sort are not applied; ordinary identity/source/assignment filters still work and
sorting falls back to last activity. Pagination metadata reports that effective
last_contact sort, rather than the ignored requested quality/score sort. Counts represent this neutral view: unknown
and all equal the matching visible Lead count, with other qualities zero. This
state is explicitly labeled by selection_required. With selection, every
qualification-dependent predicate/subquery/preload/count uses exactly that Offer.
Associated current evidence/follow-ups/bookings cannot be borrowed from another
Offer's Qualification. Related Conversation history stays separately accessible
within existing permissions.

The approved qualification-only Conversation jbuilder block uses
`conversation.offer_id` as its explicit selection and the same additive context.
It does not alter `control_state`, `control_version`, last-decision history,
control events, cockpit methods, or event payload producers. A Conversation
without selection gets the neutral qualification block when Offers exist.
R06 restrictions still hide combined Qualification evidence from a member who
cannot access all Conversations of that Lead; the Offer id does not widen access.

## Prepared acceptance checks

Read each of two Offers, show stale evaluated versus current revision, scope
sorting/filtering/counts, neutral absence-of-selection including labeled legacy
history, cross-account Offer rejection, preserved R06 visibility, and selected
Offer Conversation qualification with unchanged control fields. Existing
legacy Lead service/directory/request behavior remains a compatibility control.
No runtime result is implied by this document. Final delivery revision work
remains source-only and is not enabled by this reader decision.

## Observed reader result

Initial actual reader run9/8; first implementation9/0. Expanded12/3 included
an incorrect GET export fixture; after correcting to the existing POST endpoint,
12/2 remained (row staleness and disabled Offer question). Corrected combined
reader/edit/lifecycle/legacy/R06 run49/0. The original shared-readers snapshot
omitted LeadsDirectoryService and does not prove those results. The complete
source reproduction release records a new49/0 on immutable becb6fc with whole
repository equality before and after execution. The original refs/logs are
preserved as incomplete historical snapshots. Final delivery remains proposed.

Review then found booking predicates were still unscoped despite scoped row
bookings, and neutral sort metadata reported the ignored request. Ten focused
request examples fail before correction, including A/B confirmed, no-booking,
canceled and completed controls, all four neutral booking filters, and actual
last-contact ordering plus metadata for quality/score fallback.
