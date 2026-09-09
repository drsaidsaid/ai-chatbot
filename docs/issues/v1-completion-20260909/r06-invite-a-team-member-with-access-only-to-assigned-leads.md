# R06 — Invite a team member with access only to assigned Leads

Status: Implementing on `codex/r06-assigned-access-20260910`; R01 and R02 integrated at `5577a37ddae5f6d08b33b0b33aefe6d933d7003c`. Automated regression, lint and production build passed; browser acceptance remains pending because the Mac is locked. See `docs/releases/2026-09-10-r06/README.md`.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/13

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can invite a team member without exposing other Leads or business settings.

## What to build

Complete the standalone Admin/Team Member permission path, including invitation, assignment-based access and every alternative route to the same data. This does not introduce Online Profits coach roles.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Admin invitation, acceptance, session access and revocation form one working path in the owned authentication system.
- [ ] Team Members can view/respond/edit permitted assigned Leads and Conversations; administrators retain the documented Business Account-wide scope.
- [ ] Enforce access on APIs, search, qualification evidence, counts, exports, attachments, realtime events and direct links, not only menu visibility.
- [ ] An unrelated Lead with another Conversation cannot leak through a contact/qualification lookup or global search.
- [ ] Admin-only provider, knowledge approval and business settings are unavailable to Team Members at both UI and server boundaries.
- [ ] Verify two Business Accounts and multiple same-account assignments, including reassignment and revoked membership.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/18 (R01).
- https://github.com/drsaidsaid/ai-chatbot/issues/19 (R02).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
