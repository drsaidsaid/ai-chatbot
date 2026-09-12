# Historical R09 reader/delivery preparation

Current authority: ADR0015 is accepted and delivery increment one is allocated.
See r09-delivery-first-increment.md and the complete-source reader reproduction.
The text below preserves earlier planning history. Its old unexecuted/source-only
status is superseded; its claim of exact frozenbd6 runtime for delivery9/7 is
retracted because that freeze omitted the live LeadsDirectoryService. The raw
historical9/7 observation remains; its complete runtime identity was not captured.

## Original source-only preparation

Status: prepared, **unexecuted**. Coordinator authorized source-only specifications
and path analysis while bounded review of immutable `6dc26262b85405794c89d54decdb36fe6c382bb7`
is pending. PostgreSQL55519/Redis6421 stay stopped. No runtime, Vue, R07 cockpit,
provider, consent or control implementation is changed by this preparation.
No red/green result is claimed for either new file.

Prepared request specifications:

- `spec/requests/ai_lead_employee/offer_shared_readers_spec.rb`: five examples for
  explicit Offer reads, staleness and provenance, selected-Offer directory sort,
  conservative R06 shared-Lead visibility and cross-account Offer rejection.
- `spec/requests/ai_lead_employee/offer_delivery_revision_spec.rb`: nine examples
  for actual queued message/event context; stale configuration and changed
  selection cancellation; unrelated Offer edit success/once-only dispatch;
  retained provider disable cancellation; human-answer invalidation at unchanged
  configuration; separate follow-up identity across Offers; stale follow-up
  preparation; and stale automatic handoff rejection. HTTP is stubbed in future
  execution; no live send is authorized. The successful unrelated-Offer control
  must reach provider acceptance so unrelated eligibility failures cannot fake
  a passing cancellation case. Existing first-greeting ordering stays intact.

## Proposed reader contract and affected paths

Explicit `offer_id` scopes all qualification data, filtering, sorting and counts
for a Lead view. The scoped response includes Offer identity, evaluated revision,
staleness, structured polarity/typed value/basis and source reference. A mutable
Contact-level `has_one`/`index_by(contact_id)` must not arbitrarily select among
multiple Offers. Without explicit selection, present a neutral selection state
or a labeled list; do not invent a strongest/latest qualification. The exact
unselected collection response remains to be agreed before implementation.

| Existing path | Narrow planned change / observed reason |
| --- | --- |
| `app/services/ai_lead_employee/access_scope.rb` | Add explicit Offer scoping to qualification lookup; preserve `complete_contact_ids` protection for combined evidence. |
| `app/controllers/api/v1/accounts/lead_qualifications_controller.rb` | Honor account-scoped requested Offer on show; Offer-specific next question, records and stale metadata; preserve scoped human writer. |
| `app/controllers/api/v1/accounts/leads_controller.rb` | Permit an explicit Offer filter for directory/show/export; route Offer evidence edits explicitly instead of silently using latest Conversation. |
| `app/services/ai_lead_employee/leads_directory_service.rb` | Scope preloads, filters, counts, scalar sorting and detail projection by Offer. Its current sort subquery can return multiple rows; current `index_by(&:contact_id)` discards all but one qualification. |
| `app/services/ai_lead_employee/lead_update_service.rb` | Inspect existing bulk evidence edit path before allowing Offer-context updates; identity-only edits do not choose a buying Offer. |
| `app/models/contact.rb` | Retain legacy association compatibility; introduce/use a plural per-Offer association where necessary, avoiding a wholesale replacement of unrelated callers. |
| `app/views/api/v1/conversations/partials/_conversation.json.jbuilder` | **R07 overlap: coordinate first.** Later, only qualification projection should use selected Offer/current access and scoped records. Do not replace control/cockpit/event fields or methods. |

The prepared reader tests do not expand member visibility: if a member lacks
another Conversation of the Lead, combined qualification remains hidden even
when requesting an otherwise visible Offer. Any narrower per-Offer relaxation
requires an explicit architecture/security decision and new leakage tests.

## Queued output context and affected paths

Record the qualification context used to create the content, not the current
mutable Qualification row at send time. Minimum frozen context is account/Lead,
origin Conversation, Offer id and evaluated configuration version; include the
qualification id and immutable decision id so a human correction at the same
Offer revision can invalidate an obsolete question or handoff. The exact storage
shape and any migration must be recorded as an ADR amendment before implementation.

`Message.additional_attributes.ai_lead_employee.qualification` already carries
Offer/version for normal orchestration replies. The associated OutboxEvent does
not. Follow-up Message metadata contains only follow_up_id; handoff alerts carry
origin/control metadata without frozen Offer context. `LeadFollowUp` currently
uses account/contact/stage/attempt uniqueness, so one Offer can reuse another's
logical attempt, and its related Qualification revision can mutate after scheduling.

| Existing path | Narrow planned change / boundary |
| --- | --- |
| `app/services/ai_lead_employee/offer_qualification_service.rb` | Return the exact decision identity written under the evaluation locks. |
| `app/services/ai_lead_employee/qualification_service.rb` | Extend Result compatibly for frozen evaluation context; retain legacy unscoped behavior explicitly. |
| `app/services/ai_lead_employee/orchestration/intent_processor.rb` | Copy that same context into Message, immutable decision payload and OutboxEvent. Preserve R10 metered provider client and every existing provider metadata field. |
| `app/services/ai_lead_employee/follow_up_scheduler.rb` | Persist scheduling-time context and question key; scope logical attempts per Offer; never refresh an old attempt by reading mutable current context. |
| `app/models/lead_follow_up.rb` plus a reviewed migration | Preserve historical attempts; add frozen context and appropriate Offer-aware uniqueness without assigning unscoped legacy attempts to arbitrary Offers. |
| `app/services/ai_lead_employee/follow_up_delivery_service.rb` | Check captured selection/revision/decision before materialization and copy context into Message/event. Coordinate lock order with the privately reviewed R04 patch; it is not integrated into accepted base9a. |
| `app/services/ai_lead_employee/highly_qualified_handoff_service.rb` | Under current authority locks, reject stale/mismatched Qualification before assignment; snapshot Offer and decision identity for alerts/retries. |
| `app/services/ai_lead_employee/handoff_alert_delivery_service.rb` | Preserve the handoff's original context on alert creation and retry. |
| `app/services/whatsapp/outbound_dispatch.rb` | Acquire the relevant origin Offer lock in the final authority transaction, before delivery/domain locks, without moving HTTP into the transaction. |
| `app/services/whatsapp/outbound_eligibility.rb` | Add a conjunctive current-Offer/revision/decision check to qualification-dependent automation; keep all existing eligibility checks. |
| `app/services/whatsapp/outbound_alert_authority.rb` | Validate the originating handoff context, not the notification Conversation's Offer; keep recipient/assignment/origin/consent checks. |
| `app/jobs/ai_lead_employee/outbox_dispatch_job.rb` | Retain canonical SendReplyJob dispatch; queued metadata does not replace final authority. |

Offer edits must not retroactively rewrite historical content. At final dispatch,
missing or stale scoped context is canceled/held with a stable reason rather than
silently relabeled. Legacy unscoped records need explicit treatment; no automatic
attachment to a currently sole Offer. An unrelated Offer edit must not cancel a
current reply. An Offer becoming disabled, selection changing away and back, or
new human evidence must not revive old canceled/failed/unknown work. An immutable
selection revision may be needed in addition to comparing current Offer id.

## Lock and compatibility proof required before acceptance

Current evaluation order is Conversation → Offer → Contact → Qualification.
Configuration edits lock Offer → Qualification invalidation. Canonical dispatch
locks Channel → owned Conversations (stable ids) → delivery, then evaluates
provider/domain authority. Add origin Offer locking before delivery/domain locks
and verify both legal interleavings around the final dispatching commit.

The present FollowUpDeliveryService takes FollowUp → Conversation, while dispatch
can take Conversation → FollowUp/domain record. Do not claim a new safe global
order from this inspection. Root must reconcile the privately reviewed R04 lock
patch59a3bbf, which is NOT accepted or integrated into base9a, and the exact integration state before editing shared delivery locks. Do not
copy private ancestry or replace whole shared services.

Next allocated runtime must first demonstrate actual red on the prepared tests,
then add real independent-database-worker barriers for: edit commits before final
authorization (zero provider sends), authorization commits before edit (one send
already admitted), stale handoff before assignment, and queued handoff alert after
an edit. Also exercise unchanged, unrelated-Offer and repeated-job controls. No
mocked eligibility method can substitute for the final authority transaction.

Preserve and rerun relevant existing checks as justified by edits:
`spec/requests/whatsapp_outbound_delivery_spec.rb`,
`spec/requests/whatsapp_alert_authority_spec.rb`,
`spec/requests/ai_lead_employee/ai_provider_delivery_controls_spec.rb`,
`spec/requests/ai_lead_employee/ai_provider_usage_controls_spec.rb`,
`spec/requests/ai_lead_employee/automated_contact_consent_spec.rb`,
`spec/services/ai_lead_employee/automated_contact_consent_concurrency_spec.rb`,
R06 assigned-access, follow-up scheduler/delivery and handoff service specs.
The Offer fence must not bypass provider disabled/configuration-version/UTC-day/
allowance checks, opt-out and approved reconsent, current control/assignment,
launch approval, connection health, message window/templates, alert authority,
once-only delivery, terminal failure or unknown-acceptance semantics.

No Vue or R07 cockpit work is prepared here. Those surfaces remain a separate
coordinated R09 completion slice after bounded runtime review and allocation.

## Reader execution update

The coordinator subsequently allocated shared readers and the qualification-only
Conversation projection. Its separate response contract and shared-readers release
record observed results. The reader file has12 examples after added boundaries.
The delivery file has9 source-only examples and remains unexecuted. Proposed
ADR0015 contains exact frozen decision/selection context and immutable follow-up
replacement lineage/index design for review. No delivery implementation ran.

## Authorized RED-only delivery run

On unchanged frozenbd6e54 reader runtime, the prepared9 delivery examples
executed9/7. Unrelated-Offer accepted-once and provider-disable controls passed.
No delivery/schema implementation followed. ADR0015 now includes the exhaustive
caller lock matrix for review; proof is retained in the delivery-red-lock-matrix
release. The dedicated services are stopped and the interval released.
