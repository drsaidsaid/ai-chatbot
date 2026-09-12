> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 shared Offer readers

Intermediate result at retained ref `refs/r09/shared-readers-20260911`. The
external frozen-tree.json sidecar is recorded after freezing, not inside its own
tree. All earlier R09 evidence directories and immutable refs remain unchanged.
Full R09 remains incomplete; Vue and final delivery safeguards are not finished.

## Behavior and compatible response

Explicit Offer context now governs qualification lookup, directory filters, scalar
sorting, counts, current evidence and qualification-linked follow-ups/bookings.
An absent selection returns neutral unknown/zero current qualification plus Offer
summaries and selection_required. It never chooses a highest/latest/sole Offer.
Accessible legacy history is separately labeled legacy_unscoped. Original identity,
contact and consent fields remain compatible; accounts without Offers retain
legacy qualification behavior. The response contract was documented before
implementation in docs/issues/v1-completion-20260909/r09-reader-response-contract.md.

Both row and detailed qualification show evaluated/current revisions and stale_at.
Disabled Offers remain readable as history but do not present an active next
question. Structured evidence preserves polarity, typed values, capacity basis
and source references. Cross-account Offer lookup is rejected, and requesting
an Offer does not relax R06 combined-evidence visibility.

The Conversation change is confined to its qualification jbuilder projection.
Its rendering prefix and suffix outside that block were compared byte-for-byte
with frozen64ed9bc. Ten delivery/control paths, including IntentProcessor,
Conversation model, follow-up/handoff services and canonical WhatsApp delivery,
were also verified byte-identical to64ed9bc. No R07 control/cockpit/event method
or Vue path was changed.

## Observed evidence

- Initial reader red: 9 examples, 8 failures; R06 visibility control passed.
- First implementation: 9/0.
- Expanded boundary suite: 12/3. Two production gaps were missing row stale/
  evaluated metadata and a next question on a disabled Offer. The third was an
  incorrect GET fixture for the existing POST CSV export route.
- Corrected POST fixture, before production fixes: 12/2. CSV export passed.
- Final corrected reader/edit/lifecycle/legacy/R06 compatibility: 49/0.
  Includes reader12, legacy Offer edit2, human edit boundaries7, lifecycle13,
  and existing Lead edit/directory/R06 compatibility15.

Raw logs and the partial intermediate reader source/spec copy are in evidence/.
The copy is not claimed as a complete standalone red runtime. Current complete
source and tested specifications have a SHA256 manifest. Previously successful
capacity/builtin-rule tests were not repeated because those source files did not
change during this reader slice. No assertions in the original HQ or legacy
specifications were modified.

## Remaining scope

Final delivery is source-only. Proposed ADR0015 describes immutable decision plus
selection revision context and exact logical-attempt/artifact replacement lineage
and indexes; it is not accepted and has no runtime implementation. Private R04
patch59a3bbf is not accepted/integrated9a; it changes LeadUpdateService and three
IntentProcessor non-key locks, not FollowUpDeliveryService. Root must reconcile
lock order and attempt-budget design before delivery work. The prepared9 delivery
examples remain unexecuted.

No build, browser, hooks, live provider send, deployment or commit ran. Source is
uncommitted. Dedicated PostgreSQL55519/Redis6421 are being stopped and released
for coordinator review after the final49/0 result.
