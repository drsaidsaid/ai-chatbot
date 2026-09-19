# R11 final correction evidence

This record is additive. It does not replace or alter the historical evidence in
`docs/releases/2026-09-13-r11-grounded-conversation/` or
`docs/releases/2026-09-13-r11-test-center-shortcut/`.

## Source correction

- Source commit: `2d44916c4d09e8150e5773dca23c4c8d3a9f13c4`
- Parent correction commit: `6a325896a1a2b53dd2f772b529a72fe5e9c081ad`
- Correction base: `c91767a66ee25cbcb56b025f2b2b3d25d37eadc9`
- Branch: `codex/r11-emergency-conversation-repair-20260910`

The complete correction closes the following review gaps:

- Knowledge mutations and final answer publication share a dedicated per-account
  PostgreSQL advisory authority. Final answering acquires authority, an Account
  reference lock, and Conversation in that order. The deterministic regression
  proves this order does not deadlock with Booking's Account-to-Conversation order.
- Informational questions are classified from configured Account/Offer names,
  approved source scope, bounded trusted Conversation context, and a one-turn
  clarification. Clearly unrelated questions receive the polite boundary;
  confirmed Business questions with no approved answer create Review.
- Business-scope relevance uses the same shared or selected-Offer document
  eligibility as answer retrieval, including documents available only to the
  selected Offer.
- The legacy no-Offer qualification fallback, synthetic default questions, fixed
  scoring, and unscoped evidence writes are retired. Configured Offer
  qualification, evidence editing, handoff, and booking continue through the
  Offer services.
- Pending clarification accepts bounded natural English and Swahili replies,
  resolves explicit correction or denial in textual order, and re-clarifies
  uncertainty instead of treating an earlier affirmative token as confirmation.
  Bare affirmative and negative reversals also resolve by textual order.
- Compound replies extract the substantive new question. Classification,
  approved-source retrieval, language, and message provenance use that extracted
  clause. Thus `Yes, and what does Pulse include?` retrieves for Pulse while
  `Yes, and what does Netflix cost?` receives the external-subject boundary.
- Compound extraction preserves configured names containing conjunctions and also
  recognizes a question immediately following an acknowledgment without a comma
  or conjunction. `Health and Wellness` verifies full-name extraction and
  classification. Approved retrieval is verified separately with `Growth and
  Wellness`, because the existing medical-risk policy intentionally reviews
  questions containing the token `health` before knowledge retrieval.
- Every occurrence of a configured name is protected while compound boundaries
  are collected. Repeating a conjunction-bearing name in one message therefore
  cannot expose a connector inside the second occurrence, while a real connector
  between two configured requests still separates them in order.
- Unpunctuated English and Swahili question grammar recognizes supported modal and
  productive Swahili forms while rejecting declarative fragments such as names
  beginning with `Will` or `May` and English words beginning with `Una`.
- Named-subject English grammar also recognizes bounded copular predicates such as
  availability and recording. Productive Swahili reporting stems are excluded,
  while configured subject phrases are not constrained by an arbitrary word cap.
  Swahili question signals are shared with language detection, and a Swahili-only
  approved-source retrieval verifies the extracted question's language and current
  Lead message provenance.
- Successful completion merges its final decision fields into the existing
  decision record, preserving the scope-resolution question and Lead message id.
  Provider-failure handling uses the same merge rule.
- English and Swahili terminal courtesy clauses, including `Thank you very much`
  and `Asante sana`, are removed only after polarity-event offsets are established.
  The preceding final confirmation or denial therefore remains authoritative.

## Contextual relevance correction design

The replacement classifier uses three outcomes:

1. **Relevant:** eligible approved source overlap, an exact configured Account or
   Offer name, bounded trusted Conversation context, or explicit confirmation of a
   pending scope question establishes context. An unanswered question in this
   state creates a real Review.
2. **Unrelated:** an existing explicit unrelated category, a personal-preference
   question directed at the assistant, or an external named subject establishes
   that the request is outside the configured context. This receives the polite
   boundary.
3. **Ambiguous:** the available Business, Offer, source, and Conversation context
   cannot establish either result. This receives a model-free English or Swahili
   clarification and creates no Review.

Configured names use normalized phrase matching. Multi-token configured names are
authoritative while one-word names do not override a conflicting external subject
category. An ambiguous question is stored for at most 15 minutes and bound to the
exact public clarification prompt plus the selected Offer and configuration
version. Only the next public Lead message can resolve it. A changed Offer is
re-confirmed; an intervening prompt, repeated ambiguity, uncertainty, or denial
cannot restore the old question. Accepted confirmation reuses the original
question and language and links Review to the original Lead message. A compound
replacement request instead uses the extracted new clause and current Lead message.
That resolution is persisted across retries. No external model evaluation is
required for this routing decision.

## Independent review

Independent review of exact source commit
`2d44916c4d09e8150e5773dca23c4c8d3a9f13c4` is **CLEAR** from both mandatory
reviewers. The specification reviewer found no reopened acceptance issue in
configured-name boundaries, ordered compound parsing, courtesy-tail polarity,
language, provenance, or recovery behavior. The engineering-standards reviewer
reported no actionable standards or code-quality finding.

## Shared test database incident disclosure

An initial concurrency test was mistakenly run against the shared local PostgreSQL
database `chatwoot_test` using role `ghalyasaid` on `localhost:5432`. The new
nontransactional specification truncated all tables before and after the run except
`schema_migrations`, `ar_internal_metadata`, and `installation_configs`. Cleanup
completed and no process remained. This could have disrupted another concurrent
test, but there is no evidence that another test was running. No reseed, restore,
or other write was made to `chatwoot_test`. An explicit database guard was then
added, and every later Rails run used the dedicated database
`r11_source_concurrency_test`.

No push, deployment, live provider request, customer message, or live-state
mutation was performed.
