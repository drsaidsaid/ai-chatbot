# R10 follow-up — uncertain provider accounting

Status: correction complete; coordinator integration pending.

Branch: `codex/r10-provider-controls`.
Parent correction: `4c8423adf208bba18b35952e3e5ca7391f6722df`.

## Result

Once a provider attempt has durable admission, any unexpected failure while
processing the provider response or recording its completion is classified as
`provider_accounting_uncertain`. The orchestration intent becomes terminal
through the existing provider-failure path. Recovery therefore cannot repeat a
provider attempt whose outcome may already have been accepted.

The original usage reservation stays `reserved`, preserving conservative daily
allowance accounting. No provider-produced Message or outbox event is recorded
when completion accounting is uncertain. Declared provider failures retain their
existing failed-usage and readiness cleanup behavior.

## Validation

- The first actual red proves a completion-write failure escaped, recovery made
  two identical provider HTTP calls, output was created on retry, and a second
  usage row appeared.
- The reviewer red proves a plain response-processing failure after real HTTP
  also escaped and allowed two provider calls.
- Both real HTTP/orchestration/recovery cases pass after the correction.
- The focused accounting, orchestration and provider-failure run passes **32
  examples with 0 failures**.
- Changed Ruby lint passes **4 files with no offenses**.
- Independent specification and standards rereviews found no remaining
  actionable issues after the final correction.

No frontend source, user-facing conversation text, browser behavior, database
schema, live provider, or WhatsApp delivery changed.

## Evidence

The `evidence/` directory retains both red failures and the final green/lint
results. `review.md` records the independent review and resolved finding.
`SHA256SUMS` freezes this evidence at handoff.
