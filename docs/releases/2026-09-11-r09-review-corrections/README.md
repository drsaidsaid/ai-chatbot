> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 concurrent revisions and selection authority

This is intermediate evidence, not full R09 acceptance. Base commit is
`9a834e756347822d4ae5af15f268a5e8751fc852`; the original first-seam runtime/specs
and raw logs remain retrievable from tree
`71460ac684fc0aab05aac5e78011e474165f19f8` at
`refs/r09/first-seam-20260911`. Corrected source is identified by
`sources.sha256` and `frozen-tree.json` in this directory.

## Actual findings and results

- The first two real database interleavings failed before correction: the writer
  could invalidate an evaluation before an older evaluator saved, or an evaluator
  could retain revision N while a writer committed N+1. See
  [concurrency-and-http-red.txt](evidence/concurrency-and-http-red.txt): 8 examples,
  2 failures. The six public authority controls passed. The original concurrency
  spec is preserved alongside this log, before adding waiting-request controls.
- The initial static bot-bypass hypothesis was corrected: the outer
  `AccessTokenAuthHelper::BOT_ACCESSIBLE_ENDPOINTS` already denied the real bot
  HTTP request. No reachable HTTP bot authorization bypass was demonstrated.
  No outer guard was bypassed. The new explicit User-only policy is defense in
  depth; [mutation-policy-red.txt](evidence/mutation-policy-red.txt) records one
  missing-policy-contract failure, not a successful unauthorized HTTP mutation.
- Two real requests blocked on the Conversation row were denied after membership
  or assignment revocation even before the defense change: see
  [waiting-authority-before.txt](evidence/waiting-authority-before.txt), 2 examples,
  0 failures. Those passing controls are retained.
- Corrected combined run: **16 examples, 0 failures**, with original assertions
  unchanged. See [focused-green.txt](evidence/focused-green.txt). RSpec reported
  10.61 seconds of examples and 3.67 seconds loading. Inherited enum deprecation
  warnings remain in the raw log.

## Correction and scope

Evaluation now locks and reloads Offer with `FOR NO KEY UPDATE` between its
Conversation and Contact locks, retaining that lock through the evidence and
evaluation writes. Configuration writer takes Offer before revision/invalidation
and never acquires Conversation/Contact. Source inspection found no other Offer
configuration/invalidation writer. Actual worker connections plus an observer
row-lock gate and `pg_blocking_pids` prove both interleavings without mocked locks
or persistence. Evaluation-first ends with revision N marked stale by N+1;
writer-first ends with the new threshold and revision N+1 current.

Offer mutation now calls `select_offer?` under the Conversation lock. It requires
a User and checks current membership plus administrator/current assignment
without request query cache. R07 control/status methods and existing bot endpoint
allowlist were not changed.

Focused command:

```sh
python3 tmp/r09/run.py first-seam-review-green bundle exec rspec \
  spec/services/ai_lead_employee/offer_configuration_concurrency_spec.rb \
  spec/requests/ai_lead_employee/offer_selection_authority_spec.rb \
  spec/policies/offer_selection_policy_spec.rb \
  spec/requests/ai_lead_employee/offer_qualification_spec.rb --format progress
```

This does not complete typed-field/rule semantics, capacity/allocation semantics,
final dispatch revision fencing, legacy caller lock compatibility, shared readers
or Vue presentation. No build, browser, hooks, live provider/WhatsApp send or
deployment occurred. The source remains uncommitted pending full required checks.
