# Grounded Answer and Review Request Tracer Bullet

**Status:** Replacement blocker ticket

## What to build

Connect durable AI Orchestration to approved Knowledge Items so one real Lead
question can receive a grounded AI Employee answer with verified Source
References. Missing, conflicting, unverified, sensitive, angry, unsupported, or
provider-failed cases must create safe Review Request behavior and no fabricated
fallback.

## Acceptance criteria

- [ ] An admin can create, approve, reject, deactivate, and categorize Knowledge
      Items used by the AI Employee.
- [ ] AI Orchestration retrieves only approved relevant Knowledge Items in the
      same Business Account.
- [ ] FAQ, offer, pricing, objection, and policy knowledge outrank supporting
      documents according to the PRD.
- [ ] A Lead-facing AI Employee answer records verified Source References.
- [ ] Unapproved, rejected, cross-tenant, stale, or source-unverified knowledge
      cannot appear in an Outbound Message.
- [ ] Unknown, conflicting, sensitive, angry, unsupported media, and
      provider-failed cases create a deduplicated Review Request where appropriate.
- [ ] The Lead receives only a safe boundary response or later human-authored
      answer, not invented content.
- [ ] A Human Operator answer may propose Knowledge, but proposed Knowledge
      remains unavailable until approved.
- [ ] Tests cover grounding, source priority, source verification, tenant
      isolation, review deduplication, and provider failure behavior.

## Blocked by

- Ticket 003: Secure OpenAI-compatible provider configuration.
