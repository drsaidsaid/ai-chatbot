# R10 follow-up — provider control race corrections

Status: correction candidate complete; coordinator integration pending.

Branch: `codex/r10-provider-controls`.
Original candidate: `9dfd322f00346da402f320be063206a99a88f9e3`.

## Result

This separate follow-up closes the four findings raised after the original R10
handoff while preserving its evidence unchanged.

- Provider-produced Messages retain the configuration revision and UTC usage
  period that admitted the request. Final WhatsApp authorization cancels output
  after either authority becomes stale, including across UTC rollover.
- Provider usage inside an application transaction is written synchronously
  through a bounded two-connection ledger pool. Ledger checkout failure blocks
  provider HTTP; bookkeeping failure after HTTP suppresses the output and keeps
  the reserved attempt conservative.
- A health result can update readiness only when its configuration and start
  time are current. A slow older success cannot overwrite a later real failure.
- Reviewed evaluation evidence cannot certify launch when the Business Account
  has no current provider connection.

## Validation

- The red log reproduces all four reported defects before implementation.
- The final focused Rails run covers the full R10 request/job/service set and
  passes **106 examples with 0 failures**.
- The controller and complete WhatsApp regression run passes **62 examples with
  0 failures**.
- Changed Ruby lint passes **17 files with no offenses**.
- Independent standards and specification rereviews found no remaining
  actionable issues.

No frontend source changed, so the original R10 component, production build and
desktop/phone browser evidence remain applicable. No live provider or WhatsApp
request was made.

## Evidence

The `evidence/` directory contains the pre-fix failures, focused green runs and
changed-source lint output. `review.md` records the two independent rereviews.
`SHA256SUMS` freezes the correction evidence at handoff.
