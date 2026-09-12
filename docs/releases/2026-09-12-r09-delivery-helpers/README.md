> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 delivery and cancellation helper extraction

Final source `2eb5bdb9c2431f569d76027eabcec81ad16030a3`; before production source `a5253e37a45f46e99e6af3e92139c2282f18a722`.
The delta is two production files and one committed-transaction regression spec.
The extraction plan was recorded before editing; the caller/transaction mapping
is included separately. No retry or admission semantics changed.

The Delivery relation is explicitly fully materialized before collecting the
Offer union. No batching or lock/query ordering was added. The split cancellation
SQL literal is byte-identical. Current-artifact guards and cancellation reason
selection move into methods called inside the same ownership transactions.
Every former early exit still yields nil and suppresses external dispatch; the
same recorded-event enqueue remains after the transaction blocks.

Baseline original implementation: `b1bcd055add12ca870fce70468840d591565bb7a`
passed the initial seven cases; `78e8ce9a4d01de68e5b292aff2c7308f79382f58`
passed all eight after adding a separate-connection publication check. Final
candidate passed 86 scenarios across eight files, including those eight,
admission/lifecycle worker interleavings, terminal invalidation, canonical
outcomes, lineage and delivery/scheduler behavior. Every run retains its actual
source with exact whole-tree pre/post equality; baseline counts are not combined
or relabeled as candidate results.

New committed cases assert persisted cancellation and blocked Attempts on
control/opt-out/internal-note exits, unchanged cancelled/admitted records, one
future reschedule, actual database exception rollback of Message and artifact
writes, and publication only after rows are visible from another DB connection.
The test-only CHECK constraint is dropped in after cleanup. This regression
evidence complements the installed ActiveRecord transaction implementation
reading; it does not rely solely on ensure semantics.

Candidate Rails ran03:50:14–04:17:03 UTC, with1599.913703 seconds in examples:
86 examples, zero failures/pending. The active run was preserved beyond the
04:07:01 interval deadline per coordinator instruction. Final full Ruby lint:
71 findings across90 inspected files; both edited production files and the new
spec are clean. Source equality was also checked around lint. Runtime released
04:17:49 UTC; no new heavy run, browser, server, broad build, normal-hook commit
or deployment was started. Coordinator review and browser acceptance remain.
