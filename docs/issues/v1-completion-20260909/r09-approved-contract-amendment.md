# R09 approved-contract amendment implementation

Baseline `e97b1f8bed27824068cc9ae92bccf61cb6de661f` is merged into the
reviewed R09 branch. This slice implements only the revised configurable
qualification runtime described by ADR 0016 and the 12 September product
agreement.

## Public seams under test

- The administrator Offer API round-trips explicit `not_configured`, `disabled`
  and `enabled` qualification modes, business-authored question purposes,
  requirement dimensions and the chosen next step.
- The selected-Offer qualification service creates no fabricated outcome when
  qualification is not configured or disabled. When enabled, it evaluates only
  the Offer's configured requirements and weights, asks at most one enabled
  required missing or uncertain question, and skips facts already known for that
  Offer.
- Lead and Conversation qualification payloads expose business fit, readiness
  and action eligibility separately, with reasons and missing fields retained in
  the immutable decision history.
- Sales-call handoff follows the configured next step and current action
  eligibility. It does not require a universal Highly Qualified label, fixed
  budget/urgency/authority signals or an arbitrary answer count.
- Every enabled requirement is conjunctive, even when several requirements use
  the same field. Sales-call assignment requires every current configured fit,
  readiness and action-eligibility requirement to be met, no exclusion, and
  explicit positive Lead agreement in the stable `sales_call_agreement` boolean
  field. A canonical `not_required` dimension is valid only when the current
  Offer has no enabled requirement or enabled required question for it; empty or
  malformed assessments fail closed. Basic human assistance is a separate route
  and never counts as sales-call agreement.

## Preserved boundaries

Conversation → Offer → Contact → Qualification locking, revision invalidation,
immutable evidence/decision snapshots, OfferDeliveryContext, follow-up attempt
lineage, consent and sender ownership remain unchanged. No document
interpretation, authoritative price editor, platform provider control, ad routing,
paid call, payment or booking behavior belongs to this slice.

Tests proceed as red/green behavior slices at these public seams. Focused Rails
and Vue checks run before the required R09 regression, lint and production build.
Browser validation waits for coordinator allocation after a frozen candidate.
