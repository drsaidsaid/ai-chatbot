> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 final required verification

Complete source `ee1f82ed55bd2a8878ceedc6ddef0f89b3030984`, immutable ref `refs/r09/offer-final-required-source-20260912`.

Serial required checks all passed against this exact source:

- Rails: 457 examples, 0 failures, 0 pending across 47 required files. All changed existing Ruby specs, including renamed files and the new transaction regression, are included.
- Vue: 52/52 tests passed; 0 failures.
- RuboCop: 0 findings across 98 inspected files.
- ESLint: 0 errors, 3 warnings; exact messages retained.
- Production asset build: passed.

Each invocation records its actual start/finish, command and complete source tree before/after. Every tree equals the frozen source. Full repository blob manifests before/after cover all tracked and newly added source; no runtime changes occurred during the serial run. This is the authoritative final-source test/build evidence, distinct from earlier cleanup checkpoints.

Browser acceptance is pending. Root freshly reported the Mac locked/automatic unlock unsuccessful and a browser request-header policy failure. No server was started by this task. `final-required-browser-resume.md` contains offline setup and acceptance instructions, not browser evidence. Root owns the pending unlock request and browser/server allocation. Normal-hook commit/integration/deployment remain pending root completion decisions.

The evidence tree adds only this release directory to the tested source. Private local runtime environment values are not included.
