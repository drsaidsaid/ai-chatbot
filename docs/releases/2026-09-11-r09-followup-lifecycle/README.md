# Follow-up lifecycle increment2 — verification candidate

This candidate completes the accepted ADR0015 lifecycle implementation, following
accepted increment1 e134. It is not yet accepted or released.

Migration17 separates bounded per-Offer Attempts from immutable Artifact history.
Context-only replacement preserves the same Attempt and original job/Message
identity. All admission/outcome/recovery/preparation/repair/retry/cancellation
paths use ordered ownership. Publication is M/E projection only. Consent and
control cancellation batch every Attempt before any Artifact or Delivery.

Development suite67/0 includes24 actual worker interleavings. Earlier wider
147/1 and corrected targeted7/0 remain separate evidence. Complete frozen
combined verification is pending; do not infer its result from prior runs.

The automatic inventory covers every tracked/nonignored file against accepted
base9a; all non-release repository paths have SHA256 entries, including unchanged
dependencies and LeadsDirectoryService. Source and evidence trees are separate.
All services/data/provider responses used here are local synthetic test fixtures.
No UI changes, build, lint, hooks, commits, real-provider/model HTTP or deployment.

The first combined frozen sourcea74b10aafcb8413bd4828e65ea28f6a52df03646
ran241 examples/1 failure with complete whole-tree equality before/after.
The only failure was the existing provider-revocation test's observer waiting
for the former RuntimeControl.failure_code entry point; canonical authorization
now invokes the same checks through failure_code_locked with its preowned R.
Only that observer symbol is corrected. Original setup, user input, revocation
worker, provider/version and once-only assertions are retained. Production code
and every other non-release source remain unchanged for the verified rerun.

The corrected original provider-revocation scenario ran1/0 with its actual
barrier and update worker reached. The full verified rerun is still pending.
