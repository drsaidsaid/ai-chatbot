> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 evidence lifecycle and reviewed parser/rule corrections

Intermediate result, not full R09 acceptance. Exact source/specifications/raw
proof are retained at `refs/r09/evidence-lifecycle-20260911`. The external
frozen-tree.json sidecar is written after freezing and is not inside its own tree.
All previous R09 release evidence directories are included, and all prior frozen
refs remain unchanged. Source is uncommitted on accepted base 9a834e7.

## Verified behavior

Human corrections require an explicit accessible Conversation and its selected
Offer. The writer locks Conversation, Offer and Contact in that order, checks
fresh membership/assignment and selection, records normalized human evidence,
supersedes only the same Offer/field and reevaluates. Later extraction keeps human
precedence. Human response evidence is filtered to the requested Offer. Cross-Lead,
wrong-Offer and unassigned-Conversation edits are rejected. Explicit JSON false
is retained as a negative typed custom answer with its human provenance.

New observations retain the field definition used to interpret them. Used keys
cannot silently change meaning/type/period/options/currency, including after an
archive/reintroduction. Prompt changes remain allowed. Configuration updates
retain evidence, mark only their Offer stale and preserve historical decisions;
reevaluation uses the new revision. Old-message replay does not restore superseded
evidence; obsolete question revisions cannot bind new custom answers.

The second reviewed capacity correction required one more refinement: generic
extract_problem presence was insufficient to prove independence. Pronoun-linked
needs for groceries or bank approval could become both false budget and false
problem. Independence now requires anchored supported authority, concrete business
need or contact assertions, with financial dependencies excluded. A retained
financial tail is excluded from the generic buying-fact pass as well as making
capacity unknown. Tests preserve real independent English/Swahili business needs,
authority/problem uncertainty and explicit replacement budget amounts.

Built-in inquiry-volume observations now contain numeric typed_value, and supported
authority observations contain true/false typed_value. Unknown authority remains
unknown. Saved numeric comparisons and boolean equality therefore match actual
inbound evidence. A false-authority hard exclusion overrides a matching 200-point
score rule; positive/unknown controls are retained.

## Observed runs

- Prior lifecycle red (retained in typed-capacity release): 13 examples, 2 failures.
- Initial lifecycle correction: 13/0.
- Added edit/archive/currency boundaries: 7/1, exposing JSON false normalization.
- Corrected lifecycle + boundaries + R06 assigned-access: 28/0.
- Initial built-in typed rules: 3/3; expanded false-authority controls: 6/4.
- Complete review regression including a 200-point hard-rule control and EN/SW
  financial dependencies: 17/12. Five independent/correction/positive/unknown
  controls passed on the red runtime.
- Corrected focused run: 69/0. Includes all 52 preceding capacity/allocation/
  correction cases, original unchanged HQ job and Offer capacity scenario.
- Final compatibility: 91/0. Typed/rule33, lifecycle13, human-boundaries7,
  R06 assigned-access8, first-seam/concurrency/authority16 and legacy service14.

All raw outputs are in evidence/. Intermediate red source copies are explicitly
partial, not claimed as complete standalone runtimes. Current complete runtime
and tested specifications have a SHA256 manifest. The original HQ job example and
legacy qualification-service specification remain unchanged from accepted base.
No original assertions were weakened.

## Scope and limitations

This does not complete shared per-Offer readers, Vue Offer/Lead/Conversation
screens, final dispatch/handoff/follow-up revision fences, broad multilingual
understanding, full lint/build/browser/review/commit or migration deployment.
The field-definition safeguard covers new Offer evidence that records its
interpreting definition; no fabricated legacy meaning backfill is claimed.
No R07 cockpit methods were changed. No live provider/WhatsApp sends, build,
browser, hooks or deployment ran. Dedicated PostgreSQL55519 and Redis6421 are
being stopped and released for coordinator review after these verified runs.
