# ADR 0018: Supervised owner pilot authority

Status: Proposed — pending root acceptance

## Context

The normal Launch Gate and customer AI Reply Credit controls correctly keep live
automation unavailable. A supervised owner-funded pilot needs a narrower path to
exercise the same production orchestration and WhatsApp delivery code for one
explicit Lead without enabling the Business Account generally or charging the
customer's subscription allowance.

The provider usage ledger records every application HTTP attempt, including
failed and uncertain attempts. Provider cost is learned after a response, so a
local cost sum alone cannot promise an absolute USD ceiling. OpenRouter documents
per-key USD limits and guardrail budgets, but the pilot must retain a concrete,
sanitized verification snapshot for the dedicated key or guardrail used. Operator
assertions and free-form text are not proof of a provider-side limit.

References:

- https://openrouter.ai/docs/api/api-reference/api-keys/get-current-key
- https://openrouter.ai/docs/guides/features/guardrails/overview

## Decision

Introduce a `PilotAuthorization` as a separate, expiring authority. It binds one
Business Account, Inbox, Lead, Conversation, recipient identifier, Conversation
control revision, AI Provider Connection revision, attempt limit, and owner-funded
USD target. Activation requires a Platform App with a dedicated pilot-operations
permission and a successful provider-limit verifier. Only sanitized evidence is
stored; provider management credentials are never persisted.

Normal Launch Gate behavior remains the default. While it is closed, inbound
orchestration may be recorded only when an exact current Pilot Authorization is
found, and the authorization identity is carried through the intent, provider
usage, outbound message, and dispatch checks. Pilot answers do not reserve or
settle customer AI Reply Credits.

Provider admission serializes on the Pilot Authorization before the existing
provider connection lock. Each provider HTTP attempt creates one linked usage
row. The attempt limit rejects later admissions; it does not invalidate delivery
of an answer produced by the final admitted attempt. A recent in-flight attempt
temporarily denies concurrent admission without pausing the authorization. An
uncertain outcome, a stale reservation, missing cost, scope drift, provider
revision change, expiry, pause, revocation, takeover, opt-out, or other existing
authority failure blocks later automation and dispatch.

The verified provider limit is an outer risk control, not a claim that the
provider cannot overshoot its configured limit. Local admission also stops when
known linked cost reaches the owner-funded target. Evaluation runs remain
non-deliverable and outside this pilot authority.

## Lock order

Pilot admission uses Pilot Authorization, then AI Provider Connection, then the
provider usage row. Outbound dispatch preserves the existing Channel,
Conversation, Offer order, then locks Pilot Authorization before AI Provider
Connection and the remaining canonical delivery authorities. Provider HTTP stays
outside database locks.

## Test seams

The public seams are inbound intent recording, metered provider completion,
canonical outbound eligibility/dispatch, and the Platform pilot-authorization
API. Tests use fake adapters and prove exact scope, permission, expiry, revision,
takeover, concurrency, attempt exhaustion, ambiguous cost, stale dispatch, and
absence of customer billing.

## Consequences

No pilot record is seeded by this change. Proposed values such as USD 2 or 30
attempts remain proposals until an authorized Platform Operator activates a
record with verified provider-limit evidence. Full R17 readiness, deployment,
real sends, and customer billing changes remain outside this bounded increment.
