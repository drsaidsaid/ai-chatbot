# R06 — Invite a team member with access only to assigned Leads

Status: Draft for breakdown review; not published and not assigned.

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

- R01 (replace with the published GitHub issue reference after approval).
- R02 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
