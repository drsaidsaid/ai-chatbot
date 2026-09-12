# Pre-commit path safety follow-up

Reviewed R09 checkpoint `b78b7053fd09794a6db91e4b761c6472997df902` is preserved. Its normal hook ran without bypass, but two existing macOS xargs expansion errors were masked by `|| true`: only 61 clean Ruby invocations appeared for 96 staged Ruby paths. The checkpoint exactly matches its packaged tree; no hook source changes occurred. The authoritative full R09 lint/test/build evidence remains valid, but complete checkpoint-hook coverage is not claimed.

Candidate source `4fb90d61fb9fa977957b4d4b27109059e072995c` changes only `.husky/pre-commit` and adds `spec/system/pre_commit_spec.rb`. Application/runtime files are unchanged. Root review is required before the separate normal-hook follow-up commit; no amend, push, integration, issue closure or deployment is performed. Browser acceptance remains externally blocked.

## Fix

The existing lint-staged command stays unchanged. Git paths are read with NUL delimiters and passed as individual Ruby subprocess arguments, avoiding shell interpolation and macOS xargs replacement limits. The same existing staged files are selected; the same Ruby extension filter, RuboCop flags and restaging scope remain. Every eligible Ruby path is checked even when another fails. Enumeration, Ruby-check and staging failures now produce a failed hook rather than being silently ignored. No linter rule, formatter policy or exclusion changes.

## Validation

Six public-hook scratch-repository tests pass against the exact frozen source. Real Git and the actual Husky bootstrap are used, with executable stand-ins only for the external formatter/linter commands. Tests cover ordinary, spaced, newline and long filenames; all eligible paths formatted and staged; non-Ruby evidence and unstaged files untouched; absent files skipped; Ruby failure while continuing coverage; real Git index-lock staging failure; missing repository enumeration failure; and existing lint-staged failure propagation.

Four red/green cycles retain exact source refs, invocations, counts and complete before/after identity. Each red failed on its intended behavior before its narrow fix. The final six-example run has zero failures/pending. The test file and inline Ruby are lint-clean; shell and Ruby syntax checks pass. The public command tests are under the existing system-spec convention. No new lint suppression/exclusion was added.

The initial macOS failure was also reproduced using one actual 155-character evidence path; an argument-based invocation round-tripped it without changing repository state. Logs and diagnosis are retained. Full product tests are not re-attributed to this hook-only source.
