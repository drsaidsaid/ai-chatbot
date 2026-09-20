---
status: accepted
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

When an inbound turn needs free-text interpretation for a pending configured
question, use the existing managed, metered provider attempt for one strict JSON
response. Supervised pilot authorization may fund that attempt while the Launch
Gate is closed; ordinary live accounts use the existing Launch Gate and customer
AI Reply Allowance controls. The response may propose: a brief reply, evidence
candidates keyed to current configured fields, and language renderings of the
current owner prompts. In the already-authorized pilot grounded-answer path, the
same JSON envelope may carry the grounded reply. The provider may not select an
Offer, make a qualification or handoff decision, create requirements, infer
action or appointment agreement, or invent a question.

The prompt contract supplies the actual enabled field keys, owner prompt,
meaning, answer type, options, Offer currency, period, requested language and
pending question context. Local validation then checks every candidate against
the current tenant, Offer and captured configuration/selection revision: key
allowlist, type/options/currency/period, asserted and certain status, exact text
from the persisted incoming Message, and the containing Lead clause so a short
quote cannot remove negation, future/goal or third-party context. Goal and
negative facts are accepted only when the configured field meaning/prompt asks
for that fact; otherwise they remain ambiguous and are skipped. Duplicate
conflicting candidates for one field reject that field for the turn rather than
letting the last model value win. Invalid candidates are discarded. Existing
deterministic Offer rules evaluate only persisted validated observations and
select the next missing configured question after that evaluation. Explicit
action agreement continues to require the current proposal/action binding and is
never inferred from generic interest.

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

The provider request is outside database locks. Before that request, the
application captures the exact Offer id, Offer configuration version and
Conversation offer selection version. On return, it rechecks Conversation
control and provider authority, then locks in ADR0014 order: Conversation,
captured Offer, Contact. Structured observations are written only if the same
Offer remains selected, the selection version is unchanged, and the captured
Offer is still enabled at the same configuration version. Grounded source
authority is still rechecked on grounded-answer paths. Existing pilot
authorization, provider usage, reply allowance, canonical dispatch and review/
human/stop precedence remain in force. One inbound turn has at most one managed
provider admission.

## Consequences

This is a generic configured-Offer response format layered on the current
managed provider, not a second extraction provider or a free model call. The
pilot path changes funding/Launch Gate admission only; it does not make the
parser product behavior pilot-only. Fake adapters cover the untrusted response
contract. Missing knowledge, malformed output, ambiguity, provider failure,
authority drift, stop and human priority retain their existing safe behavior.
