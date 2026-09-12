# R09 UI review corrections and required-check evidence

Source: `be40e2c6f63a23420fcce99cb9f605c89ce703aa` (`refs/r09/offer-verified-source-20260912`).
This is a development checkpoint. R09 acceptance, normal-hook commit, browser
verification and integration remain subject to coordinator review and cleanup.

## Corrections

- Account + Offer request identity clears tenant-derived Lead state synchronously;
  obsolete results/errors cannot repopulate it. Per-operation ownership releases
  export/re-consent busy state without letting an old account clear a newer operation.
- Authorized evidence source Conversations are fetched in one query per bounded
  20-row projection, preserving account/assignment restrictions.
- Explicit currency edits update money-rule currencies while retaining exact
  decimal amounts; rejected drafts remain editable. The canonical prohibition
  on changing used money-field currency remains unchanged.
- The acceptance path saves a money rule/revision, processes canonical incoming
  evidence, and reads the correct scoped score, next question, revision and source link.

## Evidence interpretation

Every listed run retains its own source identity, exact before/after Git tree
proof, invocation, result and log. Do not add totals or relabel earlier source runs.
`ui-required` is the 447-example run with seven legacy fixture failures.
`ui-busy-fixtures` fixed those seven with assigned Conversations and provider
revision-stamped review fixtures; its one remaining failure was a newly added
assertion at the wrong policy layer. `ui-affected-final` moves that assertion to
the existing complete-contact Scope contract and preserves production policy.
Final actual outcomes are in `r09-verified-verification.json` and `test-summary.json`.

The final whole-tree manifests cover every non-release path and every changed
runtime/test path, with no Git-blob mismatch. The evidence envelope changes only
this release directory relative to the source tree.

## Lint provenance and remaining work

Accepted base `9a834e756347822d4ae5af15f268a5e8751fc852` and reviewed UI source
`e82a6c0c200e0dc9d2dc8c8de0e58a7a9b199648` were materialized with exact Ruby
source/configuration hashes for independent lint comparison. Initial baseline
attempts inside ignored tmp directories inspected zero files and are not valid
lint evidence; the recorded corrected invocations use external temporary roots.
The valid accepted-base check found Account class length177/175. The e82 check
found476 offenses, including Account length178/175:378 style/spec conventions,
81 complexity reports,17 other Rails/Lint/Performance reports. Prior development
checkpoints do not make those R09-created findings accepted baseline debt.
Current final lint results are retained separately; no lint rules were disabled
and no blanket exclusions were added. Remaining R09 lint cleanup blocks commit.

No browser or server was allocated. No deployment or normal-hook commit occurred.
