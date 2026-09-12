# Hook option-like pathname correction

This supersedes the uncommitted hook candidate from the prior path-safety package. Root identified that a pathname such as `--require=payload.rb` could be interpreted by RuboCop as an option. The hook now inserts the `--` option terminator before each pathname. No formatter/linter flags, eligible-file scope or application code changed.

Red source `a5c53493e7649807cbdf25c9ff9f0af1f776332b`: all six prior cases passed and the new option-like pathname case failed because it was parsed as a linter option. The executable linter stand-in now separates and validates command/options/pathnames, instead of assuming every argument after the initial flags is a filename. It rejects unexpected options without executing Ruby payloads.

Green source `202e5c6d590dba3c8d5ff6ad100f7a1ea76d2944`, ref `refs/r09/hook-option-path-green-source-20260912`: seven tests pass, zero failures/pending. Full source before/after equal. Test-file and inline-Ruby lint have zero findings; shell/Ruby syntax pass. The application source remains identical to reviewed `ee1f82ed`; only the hook and its system regression differ outside release evidence. No application tests/build rerun is attributed to this hook-only change.

Checkpoint `b78b7053fd09794a6db91e4b761c6472997df902` remains unchanged. Narrow root review is pending before a separate normal-hook follow-up commit. Browser acceptance remains externally blocked. No push/integration/deployment/issue closure performed.
