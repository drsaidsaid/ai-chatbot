# R05 — Honor a natural-language stop request in the live conversation

Status: Approved for implementation; blocked by the issues below.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/10

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Lead can ask to stop and the app immediately stops automated contact.

## What to build

Wire opt-out recognition and persistence into canonical incoming processing and dispatch cancellation, with a clear status in the Conversation and Lead detail.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] English, Swahili and mixed-language stop/refusal cases are tested with explicit distinction between opting out and unrelated negated phrases.
- [ ] A recognized opt-out is stored durably with source message/time and appears in the authorized operator view.
- [ ] Pending AI messages and follow-ups are canceled or blocked at dispatch; repeat events do not create duplicate effects.
- [ ] Reordering, retries, later takeover and restart cannot silently restore messaging eligibility.
- [ ] Re-consent requires a new explicit supported action and recorded evidence; resuming AI alone does not clear opt-out.
- [ ] Prove canonical ingress → recorded stop → blocked send with an isolated provider and queue.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/20 (R03).
- https://github.com/drsaidsaid/ai-chatbot/issues/21 (R04).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
