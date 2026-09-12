# R09 root review findings and correction contract

Date: 2026-09-12
Review mode: read-only two-axis review of the frozen source, followed by an authorised correction slot
Fixed point: `5c1a9624a64adcad72855c3e4a489921f116816e`
Frozen source: `1e460bb20de3193c4376faf7b415fe081b63eee3`
Diff reviewed: `git diff 5c1a9624a64adcad72855c3e4a489921f116816e...1e460bb20de3193c4376faf7b415fe081b63eee3`

The Standards and Spec axes independently examined the two root concerns. These findings supersede the earlier recommendation in `final-amendment-code-review.md` to gate only on action eligibility: the normative Product Agreement requires current approved fit/readiness requirements and the Lead's agreement, while the R09 amendment also requires current action eligibility.

## P1: requirements for the same field overwrite one another

`OfferRules.normalize` accepts every configured rule and `OfferRules#requirements` returns every enabled requirement. In the frozen source, `OfferQualificationService#assessment_for` converted those requirements to a hash keyed only by `field`. A second rule for the same field silently replaced the first before the dimension status was calculated.

A valid range such as `revenue >= 1_000_000` and `revenue <= 10_000_000` was therefore order-dependent: with the upper bound last, revenue below the lower bound passed; reversing the rules allowed revenue above the upper bound to pass. This violates the amendment's requirement to evaluate the Offer's configured requirements and can produce a false fit result without an error.

The regression seam is the administrator Offer API plus the persisted Qualification assessment. It must prove both rules survive round-trip, `5_000_000` meets the fit dimension, and `500_000` and `15_000_000` do not meet it in both saved orders. Missing fields and reasons remain deduplicated when a required question and a rule share a field.

## P1: automated sales handoff is permissive and fails open

In the frozen source, `HighlyQualifiedHandoffService#qualification_action_allowed?` accepted a configured `sales_call` when every assessment value had status `met` or `not_required`. It did not reject an Unqualified result forced by a hard rule and did not require explicit Lead agreement. An empty assessment passed Ruby's vacuous `all?`; malformed assessment data was not validated.

This path is automatic. `IntentProcessor#process_grounded_answer!` qualifies the Lead, then `qualification_result_response` calls `create_highly_qualified_handoff` before the normal answer path. An Offer with no readiness/action prerequisites could therefore autoassign after unrelated evidence. A hard exclusion could set `quality` to Unqualified while the separate dimension assessment remained fully met or not required, and the service could still create the handoff.

The approved gate is: selected enabled Offer with `sales_call`; Qualification not excluded/Unqualified; well-formed current fit, readiness and action-eligibility assessments all `met`; and explicit positive boolean evidence under the stable Offer field `sales_call_agreement`. Missing, malformed and `not_required` assessment states fail closed. This is a sales-call rule and does not restore universal budget, urgency, authority, fixed questions or an answer count. Basic human assistance remains a separate route and does not imply agreement.

Required regressions cover:

- all configured dimensions met plus explicit agreement creates one handoff without requiring Highly Qualified;
- the same fit/readiness/action evidence without explicit agreement creates no handoff or assignment;
- a matched hard exclusion creates no handoff even when all dimensions and agreement are otherwise met;
- empty and malformed persisted assessments return no handoff without raising;
- unrelated evidence with absent readiness/action prerequisites creates no handoff;
- existing Offer revision, evidence correction, delivery admission and retry tests use an explicitly configured agreement and retain their original authority assertions;
- the settings UI can add the stable boolean Sales Call Agreement field; requesting basic human help remains outside the sales-call handoff.

## Frozen-source test gaps

`offer_qualification_modes_spec.rb` covered only the successful case where fit, readiness and action eligibility were all met. `offer_typed_field_rules_spec.rb` proved a hard rule could override score but never passed that result into handoff. The service and delivery-context specs covered legacy Highly Qualified evidence, locking, revisions and retries without the amended agreement contract. No test covered repeated requirement rules for one field, empty/malformed assessments, hard-excluded handoff, absent agreement, or a sales-call Offer with no prerequisites.

## Status

Both findings block integration of frozen source `1e460bb2`. The authorised correction now preserves every requirement state, deduplicates public missing fields/reasons, and validates the full canonical assessment shape before handoff. It rejects Unqualified results, requires explicit positive boolean agreement evidence, and exposes the stable agreement field in the existing settings panel. Delivery revision/race tests now begin from an otherwise admissible handoff and include a successful control case, so their nil outcomes continue to prove the intended authority boundary.

The completed evidence is 59 focused Rails behavior/delivery examples, 47 additional amended Offer examples, 11 authority/concurrency examples and 9 Vue tests, all passing; focused RuboCop reports no offenses and ESLint reports no errors. Deployment, browser work, production build and provider calls remain outside this correction slot.
