# Secure OpenAI-Compatible Provider Configuration

**Status:** Replacement blocker ticket

## What to build

Add the provider-neutral AI configuration needed by AI Orchestration. OpenRouter
is the initial provider, but the code must use an OpenAI-compatible adapter
interface, encrypted server-side credentials, admin-only configuration, and
classified provider failures.

## Acceptance criteria

- [ ] An admin can configure, rotate, disable, and health-check the AI provider
      for one Business Account.
- [ ] Team members cannot view, create, update, or infer provider credentials.
- [ ] Raw API keys are encrypted at rest, redacted from logs, and never returned
      to the browser.
- [ ] The adapter sends OpenAI-compatible requests to the configured provider
      without hard-coding OpenRouter into domain services.
- [ ] Provider timeout, authentication failure, rate limit, invalid response,
      safety refusal, and transport failure are classified.
- [ ] Provider failures create safe AI Orchestration outcomes and do not produce
      fabricated fallback answers.
- [ ] Tests cover tenant isolation, role authorization, secret redaction,
      provider request shape, credential rotation, and each failure class.

## Blocked by

- Ticket 002: Durable AI Orchestration intent and outbound boundary.
