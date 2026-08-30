# Secure OpenAI-Compatible Provider Configuration

**Status:** Implemented in `codex/003-secure-openai-compatible-provider-config`

## What to build

Add the provider-neutral AI configuration needed by AI Orchestration. OpenRouter
is the initial provider, but the code must use an OpenAI-compatible adapter
interface, encrypted server-side credentials, admin-only configuration, and
classified provider failures.

The implemented slice records the hard-to-reverse storage and adapter decision
in ADR 0007. It deliberately keeps ticket-002 placeholder orchestration free of
model calls with Lead content; grounded answer work will invoke the configured
provider after source verification in ticket 004.

## Acceptance criteria

- [x] An admin can configure, rotate, disable, and health-check the AI provider
      for one Business Account.
- [x] Team members cannot view, create, update, or infer provider credentials.
- [x] Raw API keys are encrypted at rest, redacted from logs, and never returned
      to the browser.
- [x] The adapter sends OpenAI-compatible requests to the configured provider
      without hard-coding OpenRouter into domain services.
- [x] Provider timeout, authentication failure, rate limit, invalid response,
      safety refusal, and transport failure are classified.
- [x] Provider failures create safe AI Orchestration outcomes and do not produce
      fabricated fallback answers.
- [x] Tests cover tenant isolation, role authorization, secret redaction,
      provider request shape, credential rotation, and each failure class.

## Blocked by

- Ticket 002: Durable AI Orchestration intent and outbound boundary.
