> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 test-only fixture state cleanup

Final formatting source: `0772958eed424906e1b6112a2fbc8dec79ef09c3`.
Only four request specs changed relative to `bf8a11c29e4af347d613baf6dc74d442b2555785`.
No production source, transaction setting, worker/queue boundary, cleanup, scenario
or assertion was changed.

## Separate verified increments

- Outcomes source `181c65fa323920c2e9a6056d7810e973f343bff1`:8 examples,0 failures.
  One-file diff; six storage slots,76 assignment/read substitutions,8 unchanged
  scenario names and42 unchanged expectation calls. Runtime6.1seconds.
- Three-race-spec source `6f6c661963a3e29618b1f18b2117c65d22b4fdf8`:37 examples,0 failures.
  Exact three-file diff;151 assignment/read substitutions. Runtime81.6seconds.
  Dynamic scenario declarations and86 expectation calls are preserved.
- Final observed-Layout-cop pass changes only formatting in two of those files.
  Parsed ASTs are identical before/after that formatting pass. The final inverse
  proof confirms that undoing only the state-storage substitution recreates every
  original normalized AST, excluding source locations.

The empty per-example Hash is memoized; fixture construction and capture remain
at the original statements in setup/helpers. Records are not moved into lazily
constructed fixture helpers. This preserves setup timing and committed-worker
boundaries. Every test invocation has exact whole-tree pre/post equality.
The8 and37 results belong to different sources; do not sum or relabel them as one
run. Full449 Rails/51 Vue/production-build evidence remains source`be40e2c6...`.

## Remaining lint

All205 instance-variable findings in the four specs are gone. Total Ruby findings
fell from352 to154. Current categories:

{
  "complexity": 78,
  "layout": 27,
  "style": 11,
  "rails_lint_performance": 18,
  "fixture_conventions": 20
}

The exact per-file/cop map is `fixtures-final-remaining-by-file.json`. Longer explicit
lookups expose some line-length/lambda-style reports; these are retained rather than
suppressed or silently mixed with behavioral rewrites. Remaining fixture conventions
include hook assertions, expectation grouping and descriptions. Production complexity,
non-local returns and lock/transaction semantics remain a separate reviewed phase.

Source manifests cover all8962 non-release files and all106 changed runtime/test
paths with no Git-blob mismatch. No browser/server, deployment, normal-hook commit,
new broad regression or production build occurred in this increment. The shared
runtime interval was released at2026-09-12 03:13:29UTC.
