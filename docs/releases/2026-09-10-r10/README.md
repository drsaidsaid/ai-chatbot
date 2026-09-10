# R10 — AI provider controls and usage visibility

Status: candidate handoff complete; coordinator integration pending.

Branch: `codex/r10-provider-controls`.
Base: `324ee6df9ca50dff708f41a4004cd105b23a784b`.
Issue: [R10 #27](https://github.com/drsaidsaid/ai-chatbot/issues/27).

## Result

Administrators can configure OpenRouter with an encrypted key, one reply-token
ceiling and a daily request allowance. The page distinguishes configuration
from readiness, reports the exact model, ceiling and configuration revision
that were checked, and shows provider failures without exposing credentials.
Health checks use the same output ceiling as real answers.

Every authorized model attempt is reserved in a durable account/day ledger
before HTTP. The ledger records purpose, requested budget, revision, sanitized
outcome, returned model, token counts and provider-reported cost when available;
prompts, replies and keys are excluded. Unknown cost remains unknown. A 32 KiB
serialized UTF-8 input ceiling, a 1–4096 output ceiling, a 15-second timeout and
no automatic HTTP retry bound provider work.

The provider connection and allowance are rechecked before model work and at
the final WhatsApp authorization boundary. Disablement, exhaustion and
configuration changes cancel pending automation. Returned output is fenced by
configuration revision. Evaluation evidence remains readable but is visibly
stale when its provider revision no longer matches.

## Validation

- Final focused Rails run: **42 examples, 0 failures**, covering admission and
  metering, health/configuration races, admin/account authorization, evaluation
  staleness, orchestration and final WhatsApp authorization.
- Final changed-Ruby lint: **33 files, no offenses**. The two guarded browser
  fixture scripts also pass lint and syntax checks. Generated `db/schema.rb` is
  excluded from the repository's changed-source lint scope.
- Provider page component run: **5 tests, 0 failures**; exact changed-frontend
  ESLint passed with no errors or warnings.
- Production Vite build: **5,078 modules passed in 2m05s** with a 4 GiB Node
  heap. The default 2 GiB attempt exhausted its heap first; no frontend source
  changed after the successful build.
- [In-app browser acceptance](browser-acceptance.md) passed at desktop and
  390×844 phone widths against the real Rails API/database and the verified
  production assets. External HTTP was blocked. The configured 512-token health
  request received only the deterministic local HTTP 402 response.
- [Standards and Spec rereview](review.md) completed with no remaining findings.

An earlier 106-example broad run exposed one transient final-dispatch race; its
exact concurrency example passed after correcting provider-dependent sender
detection. That broad run is retained as a failed historical run and is not
described as green. The broader sandbox suite also exposes a pre-existing
`booking_conflict` duplicate WhatsApp-delivery index failure. The same source
files fail at the base commit, so R10 does not hide or modify that baseline
defect.

No live provider call, real credential, paid usage, WhatsApp delivery, launch
approval or deployment was used.

## Evidence

The `evidence/` directory contains the final Rails and lint logs, schema/fixture
checks and the initial lint failure that led to the last health-check refactor.
The `browser-acceptance/` directory contains sanitized database observations.
`SHA256SUMS` freezes all release evidence at handoff.

