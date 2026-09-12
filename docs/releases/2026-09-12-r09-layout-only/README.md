> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 Layout-only cleanup

Before: `490a462a771b1e98499f6a5e811b8dc7e4d6661a`.
First pass: `a815891f08ff1fdd07ecafd29335ce12a080ce7e`.
After: `52822a3af1ea745d4680ecd6868a23e56c11ee22`.

Only explicitly listed Layout cops ran during autocorrection. The first pass
selected33 paths and changed31. The follow-up selected21 and changed9, addressing
newly exposed whitespace/alignment findings. Every selected file has identical
parsed Ruby structure before/after each pass after removing only source locations.
No semantic/style cop transformations, suppressions or blanket exclusions were used.
The inventories themselves are read-only and retain exact whole-tree equality.

The tested source remains `be40e2c6f63a23420fcce99cb9f605c89ce703aa` with449 Rails,
51 Vue and production build passing. Those are not reruns on this layout source.
See the separate98-file evidence envelope `490a462a771b1e98499f6a5e811b8dc7e4d6661a`.

## Remaining inventory

{
  "complexity": 78,
  "layout": 22,
  "style": 9,
  "rails_lint_performance": 18,
  "fixture_conventions": 225
}

`layout-final-remaining-by-file.json` maps every remaining cop/count to its file.
The final whole-source manifest includes all8962 non-release paths and all106
changed runtime/test paths, with no Git-blob mismatch.

The additional Jbuilder baseline check found5 accepted9a findings: an unused
include_cockpit variable, block length44/30, two indentation findings and modifier-if
style. E82 has3 findings, and be40 has the same three categories with block length44/30.
Combined with the prior36-file Ruby baseline check, the expanded accepted baseline
has6 findings; the two Jbuilder indentation findings are already absent. Account
class length is177/175 at accepted9a and178/175 in R09. Baseline findings are distinct
from R09-created findings and from formatting-sensitive metric counts.

## Bounded next cleanup plan

1. Finish remaining long expressions with AST-preserving line breaks where possible.
   Atomic regular expressions/long literals require a separate reviewed change and
   are not silently rewritten as formatting.
2. Start fixture-convention cleanup with only offer_follow_up_outcomes_spec.rb,
   preserving creation/capture timing, provider admissions, assertions and scenario
   coverage. Replace instance-variable storage with explicit per-example fixture
   state; rerun that file in a coordinator-allocated interval. Repeat other race
   fixture files as separate bounded increments after review.
3. Address pure Offer configuration, rule and typed-answer complexity with small
   helper extractions and the corresponding configuration/evidence request suites.
4. Review delivery lock/cancellation complexity and non-local exits separately,
   using the committed lifecycle race suite and explicit lock-order checks. Do not
   mix these with formatting or weaken existing authority/consent boundaries.

No new heavy tests/build or browser/server ran after runtime release. No normal-hook
commit or deployment occurred. Remaining R09-created lint findings, review and browser
acceptance still block ticket completion.
