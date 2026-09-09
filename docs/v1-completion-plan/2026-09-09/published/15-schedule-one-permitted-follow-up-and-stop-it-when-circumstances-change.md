# R15 — Schedule one permitted follow-up and stop it when circumstances change

Status: Approved for implementation; blocked by the issues below.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/10

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Lead who stops answering can receive the permitted reminder, and later contact stops when it should.

## What to build

Wire persisted follow-up schedules to the real incoming/qualification lifecycle, queue and outbound boundary. Present readable rules and a message/timing preview in Settings → Follow-ups.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Show readable delays such as 24 hours with explicit limits and a preview of the proposed message/eligibility.
- [ ] Canonical application events create or update durable due work; restart and missed queue enqueue recover without duplicate attempts.
- [ ] Apply the documented one incomplete-qualification reminder and optional qualified reminder limits; do not enable broad nurture campaigns.
- [ ] Recheck opt-out, Control State, closure, new Lead response, current Offer/rules and message age at dispatch.
- [ ] Use an eligible approved Meta template when required; missing/paused template or permission results in a visible blocked state, not freeform fallback.
- [ ] Takeover, reply, opt-out, configuration changes or closure cancel stale work; resume does not release an old backlog.
- [ ] Demonstrate due scheduling, one delivery, cancellation and recovery on the canonical route with fake time/provider.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/21 (R04).
- https://github.com/drsaidsaid/ai-chatbot/issues/22 (R05).
- https://github.com/drsaidsaid/ai-chatbot/issues/24 (R07).
- https://github.com/drsaidsaid/ai-chatbot/issues/26 (R09).
- https://github.com/drsaidsaid/ai-chatbot/issues/28 (R11).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
