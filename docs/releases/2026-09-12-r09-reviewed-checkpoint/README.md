# R09 reviewed code checkpoint — browser acceptance pending

The coordinator reviewed complete source `ee1f82ed55bd2a8878ceedc6ddef0f89b3030984` and final verification evidence `68f0e3fd1e483ad17134e89405ac7e14feb065a5`. All bounded source reviews are clear. Final required verification passed: 457 Rails examples, 52 Vue tests, zero Ruby lint findings, zero ESLint errors (three existing dynamic translation-key warnings), and production build. All five invocations verified the exact complete source before and after.

This checkpoint is authorized while browser acceptance is externally blocked by the Mac lock and browser request-header policy failure. It does not establish ticket acceptance, integration or deployment. [Final verification](../2026-09-12-r09-final-required/README.md) and [offline browser resume instructions](../2026-09-12-r09-final-required/final-required-browser-resume.md) are retained.

## Evidence packaging

The normal pre-commit hook auto-corrects staged Ruby files. To preserve 104 historical before/red/proof payloads, their names now end in `.rb.txt`; every byte matches the reviewed evidence tree. [The path map](historical-ruby-path-map.json) records original path, packaged path and SHA-256 for each. The immutable historical Git trees and refs are unchanged. No hook bypass, lint exclusion or product source change is involved.

Historical `.sha256` manifests describe original paths/content, including the original package README. They are intentionally retained as historical evidence and are validated after scratch restoration. Each affected folder's new `packaged-files.sha256` validates its current packaged paths/content. Current README links use this mapping and no existing Markdown link targeted a renamed Ruby artifact.

## Scratch restoration

Run `python3 restore_reviewed_evidence.py /absolute/path/to/new-empty-scratch-directory` from this package. It verifies every mapped `.rb.txt` against its recorded hash and immutable Git object, then exports the complete original reviewed evidence tree into that empty directory. It never overwrites an existing nonempty directory and does not execute any proof, test, server or hook. This restores original Ruby names, original READMEs and original historical manifests together.

Use a separate disposable test database and the recorded invocation/environment requirements before reproducing a proof in the scratch copy. Private local environment values are deliberately not included. Do not execute historical proof scripts in the packaged release directory.
