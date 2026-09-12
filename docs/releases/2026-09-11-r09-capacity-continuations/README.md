> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 capacity continuation correction

Intermediate correction; full R09 remains incomplete. Exact corrected source,
specifications and raw evidence are retained at `refs/r09/capacity-continuations-20260911`.
The external `frozen-tree.json` sidecar is recorded after freezing and is not
part of its own tree. Prior immutable capacity tree `4360f6b4011e0171eb07825d92d753a03e2972f7`
remains unchanged.

Budget extraction now keeps recognized conditional, limiting-purpose and withdrawn
capacity tails attached across but/lakini, including a following sentence beginning
with that connector. Other signals keep their existing clause boundaries. Independent
budget corrections and independent authority/problem uncertainty remain separate.
Restricted claims become unknown instead of leaving an affirmative budget prefix.

Observed runs:

- Initial red on prior runtime: 19 examples, 12 failures; seven controls passed.
- Expanded red with next-sentence variants: 23 examples, 16 failures.
- Initial correction: 23 examples, 0 failures.
- Added independent-uncertainty controls: 8 selected examples, 3 failures. This
  caught over-grouping of independent authority/problem statements; the exact
  intermediate runtime is archived in evidence/independent-red-source.
- Final correction: 40 examples, 0 failures. Includes 26 continuation tests
  (pure and actual Offer jobs), 12 existing capacity tests, the unchanged original
  Highly Qualified job example and the original Offer capacity example.
- Financial contrasts: 6 examples, 0 failures.
- First-seam, concurrency and authority compatibility: 16 examples, 0 failures.

All raw outputs are in evidence/. The original HQ job specification is unchanged
from accepted base 9a834e756347822d4ae5af15f268a5e8751fc852. No assertions were weakened.
The final run selected both continuation spec files, purchase_budget_capacity_spec,
orchestration_intent_job_spec.rb:250 and offer_evidence_lifecycle_spec.rb:8.
Financial selection was --example 'sufficient purchase evidence'; compatibility
selected the concurrency, selection authority, selection policy and original Offer
request files. Prepared remaining lifecycle and typed-rule cases have not run.

Only dedicated PostgreSQL55519/Redis6421 were used. No build, browser, hooks,
live provider sends or deployment ran. Source remains uncommitted. Services are
retained under the coordinator's allocation for the authorized next semantic slice.
This bounded evidence does not establish universal language understanding, complete
custom-rule/lifecycle behavior, final dispatch fences or finished Vue surfaces.
