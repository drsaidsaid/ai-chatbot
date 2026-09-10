# R10 — Connect and control the AI provider with visible health and limits

Status: Candidate handoff complete from accepted baseline
`324ee6df9ca50dff708f41a4004cd105b23a784b`; coordinator integration pending.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/7

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can configure the AI Employee and stop or limit its use with confidence.

## What to build

Complete the AI & testing connection panel, encrypted credentials, usage information and operational limits while retaining the owned provider boundary.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [x] Save, rotate, test and disable the supported provider through an admin-only account-scoped path, without exposing stored keys.
- [x] Persist and display health and failure reasons in plain language, with safe retry guidance and no false connected status.
- [x] Bound timeouts/retries and collect actual usage where the provider supplies it; unavailable cost data is shown as unknown.
- [x] An administrator can set a documented usage/spend guardrail or conservative enforceable equivalent and see why automation was paused.
- [x] Disabling or exhausting the permitted limit blocks new model work and pending automated delivery through the common boundary.
- [x] Model/configuration changes invalidate relevant launch evidence; test with fake provider responses before any separately authorized paid calls.

## Required predecessors (accepted)

- https://github.com/drsaidsaid/ai-chatbot/issues/18 (R01).
- https://github.com/drsaidsaid/ai-chatbot/issues/19 (R02).
- https://github.com/drsaidsaid/ai-chatbot/issues/23 (R06).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.

## Refreshed preparation

[R10 design and public acceptance boundaries](../../v1-completion-plan/2026-09-09/r10-provider-controls-preparation.md)
are reviewed against `324ee6df9ca50dff708f41a4004cd105b23a784b`, including the
integrated R04 claims/final-send checks, R02 Settings layout and R06 roles.
The observed small-probe/full-answer capacity mismatch is a required regression.
R11 owns the shared Review acknowledgment and provider-failure reply; R10 owns
honest readiness, usage/limits and the provider-permission boundary. R04's
qualification-lock correction and R09 parser work remain separately coordinated.
ADR 0012 is reserved. Runtime implementation follows this reviewed contract.
The final bounded checks, independent rereviews and in-app desktop/phone evidence
are recorded in `docs/releases/2026-09-10-r10/`.
