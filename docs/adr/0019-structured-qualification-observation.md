---
status: proposed pilot repair
date: 2026-09-20
---

# ADR 0019: Metered structured qualification observations

## Context

Offer questions are owner-configured. A Lead can answer several configured
questions, ask a relevant business question, and request a language in one
message. The legacy deterministic extractor only understands its fixed built-in
signals and treats a pending answer as a whole-message response. It cannot
safely associate arbitrary configured fields with free text.

## Decision

When an inbound turn needs grounded answering or free-text interpretation for a
pending configured question in the supervised pilot, use the existing managed,
metered provider attempt for one strict JSON response. It may propose: a
grounded reply, evidence candidates keyed to current configured fields, and
language renderings of the current owner prompts. It may not select an Offer,
make a qualification or handoff decision, create requirements, infer action or
appointment agreement, or invent a question.

The application validates every candidate locally against the current tenant,
Offer and configuration revision: key allowlist, type/options/currency/period,
an exact full-clause quote from the persisted incoming Message, asserted and
certain status, and no ambiguous, negated, future, goal, hypothetical, or
question-shaped value. Invalid candidates are discarded. Existing deterministic
Offer rules evaluate only persisted validated observations and select the next
missing configured question after that evaluation. Explicit action agreement
continues to require the current proposal/action binding and is never inferred
from generic interest.

This validation is a guardrail, not a semantic proof. The model proposes which
configured field a clause belongs to; the application verifies that the proposed
typed value is compatible with the configured field and exact quoted text. The
stored evidence keeps the quote and field definition so review can see the
semantic basis. Human-entered evidence remains authoritative and is never
superseded by extracted observations.

Localized prompt renderings are accepted only for exact current field keys. If
the requested language is Swahili and the provider omits or malforms the prompt
for the selected next field, the application omits the follow-up prompt instead
of appending the owner's English prompt. Malformed structured output creates a
review path and never sends raw JSON or parser garbage to the Lead.

The provider request is outside database locks. On return, the application
rechecks Conversation control, selected Offer and configuration/source authority
before writing observations or producing delivery work. Existing pilot
authorization, provider usage, reply allowance, canonical dispatch and review/
human/stop precedence remain in force. One inbound turn has at most one managed
provider admission.

## Consequences

This is a pilot-scoped response format layered on the current managed provider,
not a second extraction provider or a free model call. Fake adapters cover the
untrusted response contract. Missing knowledge, malformed output, ambiguity,
provider failure, stop and human priority retain their existing safe behavior.
