# Grounded Answer and Review Request Tracer Bullet

**Status:** Implemented in `codex/004-grounded-answer-review-request-tracer`

## What to build

Connect durable AI Orchestration to approved Knowledge Items so one real Lead
question can receive a grounded AI Employee answer with verified Source
References. Missing, conflicting, unverified, sensitive, angry, unsupported, or
provider-failed cases must create safe Review Request behavior and no fabricated
fallback.

## Acceptance criteria

- [x] An admin can create, approve, reject, deactivate, and categorize Knowledge
      Items used by the AI Employee.
- [x] AI Orchestration retrieves only approved relevant Knowledge Items in the
      same Business Account.
- [x] FAQ, offer, pricing, objection, and policy knowledge outrank supporting
      documents according to the PRD.
- [x] A Lead-facing AI Employee answer records verified Source References.
- [x] Unapproved, rejected, cross-tenant, stale, or source-unverified knowledge
      cannot appear in an Outbound Message.
- [x] Unknown, conflicting, sensitive, angry, unsupported media, and
      provider-failed cases create a deduplicated Review Request where appropriate.
- [x] The Lead receives only a safe boundary response or later human-authored
      answer, not invented content.
- [x] A Human Operator answer may propose Knowledge, but proposed Knowledge
      remains unavailable until approved.
- [x] Tests cover grounding, source priority, source verification, tenant
      isolation, review deduplication, and provider failure behavior.

## Implemented slice

- Durable AI Orchestration now keeps ticket-002 locking, Control State,
  assignment, inbox status, opt-out, tenant, human-reply, and control-version
  checks as the sending boundary.
- After those checks pass, orchestration retrieves approved relevant same-Business
  Account Knowledge Items, applies source-category priority, requires explicit
  fresh Source References, asks the provider-neutral AI Provider adapter for the
  final Lead-facing answer, re-runs the sending boundary, then records the
  Outbound Message and outbox event before queueing the existing WhatsApp sender.
- Unknown, conflicting, sensitive, angry, unsupported-media, stale,
  source-unverified, provider-failed, and provider-declined cases create
  deduplicated Review Requests and do not create fallback outbound content.
- Human Operator answers may propose draft Knowledge Items through the Reviews
  surface. They remain unavailable to AI Orchestration until admin approval
  writes a verified Source Reference.

## Blocked by

- Ticket 003: Secure OpenAI-compatible provider configuration.
