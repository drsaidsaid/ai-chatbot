# R06 — Invite a team member with access only to assigned Leads

Status: Local acceptance passed on `codex/r06-assigned-access-20260910` at runtime `323d381291a51ae573e0f840cec12dab2d0784bc`. Real browser corrections pass live reassignment clearing, private media denial, phone Team controls, Inbox back/focus, account revocation preserving another membership, logout media denial, final phone Save/Escape/persistence, successful re-invitation and hidden Lead/Admin-only direct links. Follow-on corrections pass 16 frontend tests, 19 membership examples, lint and the final production frontend build. Independent Standards and Spec re-reviews both have zero findings. Browser/build slots are released. Issue #23 remains open for coordinator integration. See `docs/releases/2026-09-10-r06/README.md`.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/13

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can invite a team member without exposing other Leads or business settings.

## What to build

Complete the standalone Admin/Team Member permission path, including invitation, assignment-based access and every alternative route to the same data. This does not introduce Online Profits coach roles.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [x] Admin invitation, acceptance, session access and revocation form one working path in the owned authentication system.
- [x] Team Members can view/respond/edit permitted assigned Leads and Conversations; administrators retain the documented Business Account-wide scope.
- [x] Enforce access on APIs, search, qualification evidence, counts, exports, attachments, realtime events and direct links, not only menu visibility.
- [x] An unrelated Lead with another Conversation cannot leak through a contact/qualification lookup or global search.
- [x] Admin-only provider, knowledge approval and business settings are unavailable to Team Members at both UI and server boundaries.
- [x] Verify two Business Accounts and multiple same-account assignments, including reassignment and revoked membership.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/18 (R01).
- https://github.com/drsaidsaid/ai-chatbot/issues/19 (R02).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.

## Alternative-path review follow-up

Coordinator review identified retained macro execution, Lead merge, and Contact
bulk label/deletion paths. Their HTTP/job fixes passed 79 regression examples and clean Ruby lint.
See `docs/releases/2026-09-10-r06/review-follow-up.md`; final local browser
acceptance is recorded in the release's `browser-acceptance/` folder.

## Accepted R03 predecessor refresh

Merge exact shared tip `f2b184e1c332f0bf68c31dec460f7e5599657a72` into this feature
branch, retaining the existing R06 commits. The merge applies without conflicts.
Preserve R03's direct Settings setup, encrypted credentials, phone identity,
safe health/registration and shared status projection alongside R06's minimal
member Inbox payload, assigned access and authenticated media. ADRs 0009/0010
remain separate; R04 final-send work is not part of this refresh.

Combined test/build evidence lives under `docs/releases/2026-09-10-r06/integration-refresh/`.
Local browser acceptance is complete. Shared integration and closing #23 remain
the coordinator's responsibility.

## Combined lock interaction follow-up

Combined review of tree `f2dc31d4` found a real circular wait between membership
cleanup's Account lock and R04's Conversation-locked operator-review creation.
Correction `dd49ef996b1b9e0cb1f9e5c9b356bf781e06b21f` uses Account
`FOR NO KEY UPDATE`, retaining invitation serialization while permitting Account
foreign-key checks. The actual two-connection regression fails with a PostgreSQL
deadlock before correction; the final serial suite passes 20 examples, including
both existing cleanup/invitation orderings. Lint and normal hooks pass.
Independent coordinator Standards and Spec reviews both have zero findings;
issue #23 stays open for combined integration. Accepted browser fixtures/evidence
are preserved, with no extra build or browser run.
See `docs/releases/2026-09-10-r06/combined-lock-correction/README.md`.
