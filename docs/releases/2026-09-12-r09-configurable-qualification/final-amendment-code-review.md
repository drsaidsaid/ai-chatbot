# R09 final amendment code review

Date: 2026-09-12  
Review mode: read-only, independent two-axis review  
Fixed point: `5c1a9624a64adcad72855c3e4a489921f116816e`  
Frozen source: `1e460bb20de3193c4376faf7b415fe081b63eee3`  
Diff: `git diff 5c1a9624a64adcad72855c3e4a489921f116816e...1e460bb20de3193c4376faf7b415fe081b63eee3`  
Commit list: `1e460bb2 Amend R09 for configurable qualification`

The Standards and Spec axes were reviewed independently. The review excluded later evidence commits and the separate R08/R21 integration. Passing tests were not treated as code-review evidence.

## Standards

### Hard violation: documentation flow remains contradictory

`AGENTS.md` lines 48–49 require `CONTEXT.md`, the PRD, technical design and ADRs to be updated until the current decision is unambiguous. The amendment adds persisted and public qualification modes, question purposes, requirement dimensions, assessments and next steps, but leaves `CONTEXT.md` unchanged and does not add these concepts to its required domain vocabulary.

The existing release-scope statements also conflict: `CONTEXT.md` lines 10–12 say R01–R18 are the current acceptance tickets and name the old integration branch, while ADR 0016 line 27 says R01–R18 are no longer the full launch scope and directs work to R19–R28.

### Judgment call: duplicated unanswered-question predicate

`OfferQualificationService#next_question` at lines 157–161 and `OfferQualificationReadContext#next_offer_question` at lines 117–121 repeat the same required plus absent, unasserted or unknown predicate. Put this rule behind one Offer/domain method so runtime evaluation and API presentation cannot drift.

### Judgment call: duplicated qualification-mode inference

`Offer#qualification_configured?` at lines 48–51 and `OfferConfigurationWriter#inferred_qualification_mode` at lines 142–145 independently infer configuration from the same questions, rules and score-weights trio. Migration SQL may reasonably repeat this rule for migration isolation; the two live Ruby implementations should share one domain predicate.

No other documented-standard violations were found in Rails/Vue placement, Community Edition ownership, enterprise exclusion, i18n use or behavior-spec coverage. Tool-enforced formatting and lint concerns were excluded.

## Spec

### P1: sales-call handoff incorrectly requires every assessment dimension

The approved amendment says: “Sales-call handoff follows the configured next step and current action eligibility. It does not require a universal Highly Qualified label, fixed budget/urgency/authority signals or an arbitrary answer count” (`r09-approved-contract-amendment.md`, lines 21–23).

`HighlyQualifiedHandoffService#qualification_action_allowed?` at lines 122–127 checks for the configured `sales_call` next step, then requires every assessment dimension to be `met` or `not_required`. Missing fit or readiness therefore blocks a sales call even when current action eligibility is met. The added request spec proves only the case where all three dimensions are met.

The handoff gate should check the current `action_eligibility` assessment for the configured sales-call action, with a contrast test showing that unrelated fit or readiness incompleteness does not block an eligible call.

No other missing or partial requirements, incorrect behavior or scope creep were found across explicit modes, questions, requirements, weights, one-question behavior, separate payload assessments, immutable decision history and preserved locking/revision boundaries.

## Status

Integration remains blocked by the P1 contract mismatch. The hard documentation-flow violation must also be resolved before the branch satisfies the repository delivery rules. The two duplication findings are maintainability recommendations rather than integration blockers.

Summary: Standards has three findings, with the documentation-flow inconsistency worst; Spec has one finding, the P1 all-dimensions handoff gate.
