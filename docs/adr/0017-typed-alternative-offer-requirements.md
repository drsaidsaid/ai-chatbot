---
status: accepted
date: 2026-09-20
---

# Typed alternative Offer requirements

Offer qualification keeps its existing flat typed rules and adds an optional
`requirement_groups` configuration collection. A group has one qualification
dimension and a bounded tree of typed `all` and `any` nodes. Leaves are only
existing typed Offer-field comparisons; they cannot contain code, predicates,
free-form expressions, or references outside the Offer's field definitions.

Groups are conjunctive with flat requirement rules and required questions.
Within a group, `all` requires every child and `any` requires one child. A
missing or uncertain value is not a match. For an `any` group, a satisfied
branch suppresses fields that are relevant only to another branch; a branch
known not to match does not make its unresolved fields required. Empty,
malformed, overly deep, or unknown-field groups are rejected on save and never
authorize qualification or sales handoff.

Configuration remains versioned through the existing Offer writer. Saving a
group creates the normal revision and stales prior decisions, so corrected
evidence is evaluated only against current authority. Sales-call handoff still
requires explicit positive `sales_call_agreement` evidence in addition to all
configured fit, readiness, and action-eligibility requirements.
