> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 purchase capacity and allocation evidence

Intermediate result; **full R09 remains incomplete**. Retrieve this exact source,
tested specs, manifests and logs from the retained Git tree ref
`refs/r09/capacity-20260911`. The ref is the authoritative retrievable identity;
the local `frozen-tree.json` sidecar is written after freezing and is not part of
the tree. No self-referential hash is required.

The prior correction tree remains
`609cd43b74bfd59e4f80fbc93e4adf489ab9d566` at
`refs/r09/review-corrections-20260911`. The original first seam remains
`71460ac684fc0aab05aac5e78011e474165f19f8` at
`refs/r09/first-seam-20260911`. No private pilot ancestry was imported.

## Behavior and observed evidence

Explicit purchase spending capacity is positive budget evidence without claiming
committed funds. Normalized Offer evidence and its snapshot now retain `basis`:
`capacity`, `allocation`, or `stated_budget`. Amount and currency remain exact;
Offer rules/ranges still determine sufficiency. A bare income/revenue statement,
unrelated spending, negation, conditional funding or unknown currency cannot
establish sufficient budget in the tested Offer path.

The initial scoped run on the prior correction runtime produced **11 examples,
4 failures**: missing positive capacity, missing allocation basis, the original
retained HQ job regression, and the new Offer-specific capacity path. See
[initial-red.txt](evidence/initial-red.txt).

After the initial capacity change, 11 examples passed. Three further composition
guards then exposed two failures: an unrelated contact-method choice made valid
capacity unknown, and a later funding condition was dropped as an unrelated
purpose. See [composition-red.txt](evidence/composition-red.txt). The two parser
files used for that intermediate red are preserved in `evidence/red-source/`;
the initial red runtime is retrievable from the prior correction tree.

The correction removes only the separate contact clause when reading capacity,
retains actual funding conditions before or after the spending statement, and
does not mistake unrelated purchase purposes for this Offer. Final results on
the same current source:

- **14 examples, 0 failures**: 12 pure capacity/allocation/contrast/composition
  cases, the original unchanged Highly Qualified job regression, and the new
  actual Offer job/source/basis path. See [capacity-green.txt](evidence/capacity-green.txt).
- **6 examples, 0 failures**: actual Offer jobs reject sufficient-budget inference
  from salary, revenue, groceries, denied spending capacity, conditional loan
  funding and unknown currency. See [financial-http-green.txt](evidence/financial-http-green.txt).
- **16 examples, 0 failures**: first-seam public settings/inbound behavior,
  both real revision interleavings, public selection authority, waiting-request
  revocations and the explicit mutation policy still pass after the parser
  changes. See [compatibility-green.txt](evidence/compatibility-green.txt).

The original input and expectation in
`spec/jobs/ai_lead_employee/orchestration_intent_job_spec.rb:250` were not changed.
That retained scenario now passes under the PRD interpretation recorded in
ADR 0014. No original assertions were weakened. Inherited Rails enum warnings
remain in the raw outputs.

## Exact checks and limits

```sh
python3 tmp/r09/run.py purchase-capacity-final-green bundle exec rspec \
  spec/services/ai_lead_employee/purchase_budget_capacity_spec.rb \
  spec/jobs/ai_lead_employee/orchestration_intent_job_spec.rb:250 \
  spec/requests/ai_lead_employee/offer_evidence_lifecycle_spec.rb:8 --format progress

python3 tmp/r09/run.py purchase-capacity-http-contrasts bundle exec rspec \
  spec/requests/ai_lead_employee/offer_evidence_lifecycle_spec.rb \
  --example 'sufficient purchase evidence' --format progress

python3 tmp/r09/run.py first-seam-capacity-compatibility bundle exec rspec \
  spec/services/ai_lead_employee/offer_configuration_concurrency_spec.rb \
  spec/requests/ai_lead_employee/offer_selection_authority_spec.rb \
  spec/policies/offer_selection_policy_spec.rb \
  spec/requests/ai_lead_employee/offer_qualification_spec.rb --format progress
```

Only the one capacity case and six financial contrasts in the lifecycle request
file ran. Its later correction, human-edit, typed-field and invalidation cases
remain prepared but unexecuted. The separate typed-field/rules request file also
remains unexecuted. This report does not claim complete legacy-history/human-edit
basis preservation, broad multilingual qualification, all correction semantics,
rules, custom typed answers, final dispatch revision fencing, shared readers,
full lint/review/commit readiness or Vue completion.

Runtime used only the dedicated test database on PostgreSQL55519 and Redis6421.
Both services were stopped and the heavy interval explicitly released after the
three green runs. No build, browser, hooks, live provider/WhatsApp send or
deployment occurred. Source remains uncommitted.
