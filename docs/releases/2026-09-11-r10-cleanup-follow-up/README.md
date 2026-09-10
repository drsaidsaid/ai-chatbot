# R10 follow-up — provider failure cleanup

Status: correction complete; coordinator integration pending.

Branch: `codex/r10-provider-controls`.
Parent correction: `249cb60cbab352ceeeaba3cd247e838993864ad3`.

## Result

A classified provider failure remains the terminal orchestration outcome when
either failed-usage or provider-health cleanup raises an unexpected exception.
The cleanup operations run independently, so a failed usage write does not
prevent the health update from being attempted. Each cleanup exception attempts
to log a sanitized error containing only the operation, record identifiers, the
original provider failure class, and the cleanup exception class.

When failed-usage persistence fails, the original reservation stays `reserved`
and continues to count conservatively. When failed-usage persistence succeeds,
it remains `failed` and counted even if the subsequent health write fails. No
automatic reconciliation or retry occurs. Recovery cannot repeat provider HTTP,
and no provider-produced Message or outbox event is recorded.

## Validation

- The actual red uses HTTP 402 and HTTP 429 responses through the real
  orchestration job, metered client, OpenRouter adapter and public recovery job.
- One case makes failed-usage persistence raise; the other makes provider-health
  persistence raise. Before the correction, both exceptions escaped, recovery
  made a second provider request, the intent remained processing and two usage
  rows appeared.
- Reviewer red also proves that an exception from the cleanup logger could mask
  the classified provider failure until logging became best effort.
- After the correction, both cases retain the original provider failure, make
  one provider request, terminate the intent, emit no output, keep the truthful
  usage state and attempt a credential-free cleanup error. A logger exception
  cannot change that outcome or prevent the other cleanup operation.
- The final focused provider/accounting/orchestration run passes **34 examples
  with 0 failures**. Changed Ruby lint passes **2 files with no offenses**.
- Independent specification and standards rereviews found no remaining
  actionable findings.

No frontend source, conversation text, browser behavior, database schema, live
provider, WhatsApp delivery, automatic reconciliation, or retry policy changed.

## Evidence

The `evidence/` directory contains the actual reds, focused green, final focused
suite and changed-Ruby lint. `review.md` records independent review. The checksum
manifest freezes these files at handoff.
