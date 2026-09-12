# R08 final combined verification

This package freezes final R08 verification on source commit `2d898a3d6766f9b8846f91ba90ba1056675ac56a` and tree `2fd67a4bd519ea768b1155d62a5b586bb8ccb1a3`, compared with baseline `9a834e756347822d4ae5af15f268a5e8751fc852` and tree `63204f14f911cf6acae203690274d9da4317511f`.

The selected Rails verification passed 48 examples with no failures. The two affected Vue/API suites passed 22 tests. All 13 changed Ruby paths passed RuboCop, all four changed JavaScript/Vue paths passed exact-path ESLint, and the production Vite build transformed 5,078 modules and completed successfully. The worktree was clean before verification and remains free of product-source changes after the build; only this evidence package is added afterward.

`baseline-tree-part-*` and `source-tree-part-*` are ordered multipart base64 encodings of gzip-compressed complete `git ls-tree -r --full-tree` output. Concatenate each family in lexical order, decode base64, then decompress to recover the actual whole-tree inventories. `nonrelease-complete.diff.gz.base64` is the complete binary/full-index baseline-to-source diff excluding historical release evidence. The path/status manifest, source blob-hash manifest, and runtime/test path list make the exact product scope directly inspectable. `artifact-sha256.txt` authenticates every evidence artifact except itself.

## Import boundary retained limitations

- Import accepts no more than 100 rows.
- Its one-second database lock wait and five-second pre-commit budget are cooperative: each database statement is limited to the remaining time and the service checks elapsed time between row units and before commit. PostgreSQL 16 has no native whole-transaction timeout, so this is not a hard five-second wall-clock guarantee.
- `SHARE ROW EXCLUSIVE` serializes competing R08 imports and makes each import re-resolve committed identity state under the lock. It is not a system-wide identity uniqueness guarantee. A normal Contact writer can complete its uniqueness read while import owns the lock and insert the same identity after import releases it. Raw SQL, validation bypasses, and legacy ambiguous identities remain outside this boundary.
- Exceptions raised after commit are not translated into retry-later results; a durable Contact cannot be reported as rolled back.
- The system-wide identity constraint design remains unaccepted. This release does not add a general unscoped qualification-evidence editor.

## Export boundary retained behavior

The controller creates a mode-0600 temporary artifact, registers it for Rack tempfile cleanup, and delegates file delivery through the existing Rails response path. The middleware replaces the internal file body immediately outside `Rack::TempfileReaper` with a pathless 16 KiB reader so outer ETag/sendfile layers cannot expose a path or array conversion. Authorization is refreshed before and after uncached repeatable-read generation. Normal completion, client abort, and response exceptions retain TempfileReaper ownership of close/unlink.

Earlier candidate and rejected-candidate evidence under the parent R08 release directory is intentionally retained. This final package supersedes those checkpoints only for the frozen combined source above; it does not rewrite their historical results.

Browser acceptance was not run because the Mac remained locked. No app server, integration, deployment, push, ticket closure, or R09 hook integration was performed. The isolated verification database and cache are released after the evidence commit.
