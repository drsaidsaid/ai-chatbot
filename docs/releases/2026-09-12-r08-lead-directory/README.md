# R08 Lead directory checkpoint evidence

This package records the reviewable R08 source checkpoint before integration.

- Source commit: `b690343eb2068bf394597812df8c417ec195382a`
- Parent baseline: `9a834e756347822d4ae5af15f268a5e8751fc852`
- Branch at capture: `codex/r08-lead-directory`
- Source tree: `7071d1a85b1a31a960eef1f0ab7ad3e2712e3eea`
- Capture date: 12 September 2026, Africa/Dar_es_Salaam

The five `source-tree-*.txt.gz.base64` files partition the complete `git ls-tree -r` inventory for the source commit into dashboard JavaScript, other JavaScript, other application paths, specs, and all remaining paths. Concatenating the decoded text in that order does not recreate Git's global path order, so validation sorts the combined decoded lines before comparing them with the sorted Git inventory. Decode each file on macOS with `base64 -d -i FILE | gzip -dc`. `source-diff.patch.gz.base64` is the complete binary-safe parent-to-source diff with the same encoding. `changed-source-tree.txt` lists every changed path and its committed blob identity.

The test and build logs are the original temporary logs captured during implementation. `hook-path-audit.log` is a post-commit, NUL-safe replay of Ruby lint over every changed Ruby path plus a scan for the macOS `xargs` failure patterns found during R09. The committed baseline hook contains `|| true`, so its exit code alone is insufficient evidence. The replay found no masked path error for this R08 path set.

Browser acceptance is pending. The Codex in-app browser reported that the Mac was locked and automatic unlock failed. No alternate browser was used.

This package does not claim retrospective whole-tree pre/post equality. No whole-tree pre-state manifest was captured before implementation. The complete source manifest is attributable to the immutable source commit above; individual test logs are attributable to the tested working state described in `commands-and-environment.md`.
