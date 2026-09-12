> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 spoken evidence helpers

Frozen source b35ab4204a4b2112adfc7c1d3daa4d2888d8a0bd; before source
edc76a4a4bf6874acbe183365325fd05eaf41654. The recorded plan was amended before
adding the contact helper. Seven Ruby files implement the bounded group.

Budget-tail recognition, observation projection, urgency and contact wording
move into small helpers. Existing parent APIs, contextual fallback, ordered
anchors and guarded extraction calls, financial-tail retention, evidence
replacement order, value/polarity/typed-value/basis insertion and budget basis
mutation remain. The long regular expressions use identical source strings
and options; no whitespace/flags or vocabulary are added.

95 affected Rails examples pass across eight files, zero failures/pending,
with exact whole-tree before/after equality. Complete old/new pipeline comparison
uses frozen original dependencies and matches 976 distinct regression/composed
strings across eight contexts: 7,808 comparisons, no mismatch. Seven moved budget
regexes separately match original source/options. This finite comparison
supplements the public request and extraction specs, rather than claiming
exhaustive natural-language equivalence.

All seven group files pass lint. Full changed-path Ruby inventory: 27 findings
across 95 inspected files, with exact source equality. Source manifests cover
all new paths. No new suppression, full regression/build, browser/server,
normal-hook commit or deployment. Runtime released at 04:40:05 UTC.
