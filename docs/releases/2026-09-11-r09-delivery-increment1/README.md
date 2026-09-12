> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 delivery increment one

This complete source candidate implements accepted ADR0015 normal-reply and
handoff context fences. The acceptance decision was recorded before migration
and runtime edits and retained in initial red tree9cb36071. Historical proposals
and incomplete reader snapshots remain unchanged. See the first-increment ticket
for the exact implemented scope and every remaining matrix path.

Frozen context records account/contact/origin, Offer, monotonically versioned
selection, configuration revision, Qualification and exact immutable decision id
and question key. Evaluation returns that context once; Message, event, handoff
snapshot and operator alert retain it. Explicit, automatic, removal and A→B→A
selection changes cannot revive queued content. Normal replies and handoffs check
current scoped authority; final canonical admission holds the origin Offer lock
through dispatching commit alongside all existing checks. Provider/member/alert
rows are prelocked before Delivery, and HTTP remains outside authority locks.

Initial actual16/14 and independent-worker4/3 evidence is frozen at9cb36071.
First20/0 was expanded with a different-qualification context mismatch3/1 at
3e364c81, then fixed. Unknown-after-edit and missing-context controls passed.
Expanded Offer25/0 includes six real-worker races, including both admission
interleavings and configuration/evidence writers before handoff assignment.
Legacy handoff10/8 exposed dirty CE display_id reload and duplicate-create recovery
regressions; both fixed, followed by Offer/legacy handoff28/0. The original HQ
input/expectation and existing service specifications remain byte-identical.
The copied handoff red source is explicitly partial, not a complete red runtime.

This candidate precedes final compatibility execution. It uses the automatic
complete-index snapshot and full repository manifest, including unchanged
dependencies and all changed/new runtime, schema, config and test files. Results
and whole-tree before/after identity will be appended in a separate evidence tree.

Follow-up aggregate/schema/replacement and remaining publication/outcome/recovery/
cancellation matrix work are increment two and remain unimplemented. Prepared
follow-up2 are not included in a first-increment green claim. No Vue, R07 control
behavior, private ancestry, live model/provider HTTP, build or deployment is included.

## Compatibility and alert setup diagnosis

The complete reviewed runtime eb5966e31f37866d4c6f4de249a17196c048b0ec ran
**162 examples, 9 failures**. Whole-tree equality passed before and after. All9
failures were alert-suite before hooks: no actual alert body ran. The other153
passed, including the25 Offer checks, existing R10 delivery/usage, consent and
consent races, canonical delivery/unknown/crash/once-only, handoff/control, R06,
selection authority/concurrency, shared readers and the unchanged original HQ.

Diagnosis compared actual immutable blobs: ReportBuilder, evaluation factory and
alert spec in that failed run are identical to accepted9a. ReportBuilder requires
a current provider connection and matching provider_snapshot.configuration_version.
The old alert helper created neither a connection nor a versioned provider
snapshot. Its existing reviewed_pass rows were excluded, so real approval blocked.
Accepted9a's outbound-delivery and R10 helpers already supply those prerequisites.

The only correction is in alert test setup: create the synthetic provider
connection and stamp its actual provider/model/configuration_version into existing
reviewed fixtures. All real approval calls, thresholds and behavioral assertions
remain. No production evaluator, factory default, gate or runtime change.
The full9 alert bodies and existing ReportBuilder4 plus LaunchGateEvaluator
approval-blocking case then passed14/0. These include missing/stale provider
rejection, qualification accuracy and serious-issue boundaries. No new duplicate
approval tests were added. A corrected complete snapshot precedes the final14
identity-verified rerun. The prior153 passing cases have identical source/test
blobs; repeated earlier runs are not additional distinct checks.

## Final evidence and limits

Corrected complete source: e1344a6c5976cfc8e76e896da253faa268dead74,
refs/r09/delivery-increment1-verified-source-20260911. The final alert/approval
rerun passed **14 examples, 0 failures**, with whole repository equality before
and after. All8941 non-release paths have hashes and all62 changed runtime/test
paths relative accepted9a are enumerated automatically. The sole non-release
delta from reviewedeb5966 is the alert test prerequisite fix; every production
file and all other test blobs are identical. Machine-readable parity, full
invocation lists and before/after identities accompany the raw logs.

There are **167 distinct passing checks across compatible snapshots**:153 passes
from the recorded162/9 run, plus9 successfully rerun alert bodies and5 approval
checks. This does not claim a single167/0 run. Earlier25/28/14 results are repeated
evidence and are not added to that total. The original162/9 setup failure log
and every earlier source/evidence reference remain preserved.

Both first-increment code reviews were clear before the narrow fixture correction.
The first increment is ready for final coordinator review. Logical follow-up
attempts, immutable replacement and remaining ordered outcome/publication/recovery/
cancellation paths remain increment two; fullR09 and Vue remain incomplete.
No prepared follow-up success, full-matrix completion, build, lint, hooks, commit,
live provider/model call or deployment is claimed. Dedicated PostgreSQL55519 and
Redis6421 stopped successfully and the listener check is empty; interval released.

The final frozen-tree.json sidecar is written after the evidence tree is retained,
and is not part of its own immutable tree.
