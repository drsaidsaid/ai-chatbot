# R09 optional-dimension resolution review

Date: 2026-09-12
Review mode: independent Standards and Spec review after test-first correction
Fixed point: `0f2a26971e3a4ccbc68f744db652271735c39591`
Corrected source: `50df1a0433de3911e1a39e5d25ad1ef5a63b8b26`
Corrected tree: `4d46d1e29e63a30263a507a0558ed9e3fd02cb2f`
Source range: `git diff 0f2a26971e3a4ccbc68f744db652271735c39591...50df1a0433de3911e1a39e5d25ad1ef5a63b8b26`
Normative contract: `docs/v1-alignment-2026-09-12/PRODUCT_AGREEMENT.md`

## Resolved contract mismatch

The initial root correction rejected every `not_required` assessment dimension. That was stricter than the Product Agreement, which makes fit/readiness requirements business-defined and says missing criteria do not restore fixed gates. The red regression used a sales-call Offer with one met fit requirement, explicit positive agreement, and no enabled readiness or other action-eligibility requirement. Its canonical assessment was `met`, `not_required`, `not_required`, but the handoff was denied: 10 examples, 1 failure.

The corrected gate requires all three dimension records to be present and well formed, then compares each record with the current revision-locked Offer. A dimension containing an enabled requirement or enabled required question must be `met`; a truly unconfigured dimension must be canonical `not_required`. Missing, malformed or configuration-inconsistent records fail closed. Hard-rule Unqualified results and missing agreement still block assignment independently. Disabled requirements and disabled required questions do not manufacture prerequisites.

The focused regression then passed with 10 examples and 0 failures. The broader qualification, typed-rule, reply-context, revision and delivery-admission suite passed with 59 examples and 0 failures. Focused RuboCop inspected three changed Ruby files without offenses.

## Independent review findings

The Spec review found no runtime or test-contract defect. It confirmed that configuration-inconsistent `not_required` data is rejected, canonical optional dimensions are admitted, agreement and exclusion remain mandatory, and `OfferDeliveryContext` preserves current revision authority.

The Standards review found no runtime or tenancy defect. It required the dated `root-review-findings.md` artifact to remain byte-for-byte unchanged and required the new behavior and checks to be recorded separately in the release index and manifest. This follow-up artifact preserves that history; the new logs are tracked and authenticated separately.

The final source range contains no provider, deployment, production build or browser changes. Heavy build and browser acceptance remain coordinated outside this correction slot.
