# R10 uncertain-accounting rereview

## Specification review

The independent specification review confirmed that the completion-write test
uses the real orchestration job, metered client, OpenRouter adapter, HTTP request,
durable reservation and public recovery job. It found no missing assertion in
the one-request, terminal-intent, no-output and retained-reservation proof.

## Standards review

The initial standards review identified one additional boundary: an undeclared
exception during adapter response processing could occur after HTTP but before
the response reached completion accounting. That exception could leave the
intent recoverable.

The correction now preserves declared provider failures and converts every
other post-admission adapter/response-processing exception into the same terminal
accounting-uncertain result. A second real HTTP regression reproduced the retry
before this change and passes afterward. Final rereview found no remaining
actionable issue.
