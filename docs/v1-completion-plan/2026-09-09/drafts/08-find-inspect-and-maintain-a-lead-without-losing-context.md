# R08 — Find, inspect and maintain a Lead without losing context

Status: Draft for breakdown review; not published and not assigned.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/13

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Human Operator can find an assigned Lead, understand the next action and open the correct Conversation.

## What to build

Complete the Lead directory, profile and permitted data-maintenance path using a readable desktop table and compact phone filters.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Names and next actions retain useful space; selected detail opens on demand and does not force unreadable table columns.
- [ ] Search/filter/sort/pagination preserve context when opening and returning from a Lead; distinguish no results from no data and offer reset.
- [ ] Desktop rows can be opened with a keyboard; every filter and icon action has a meaningful accessible name.
- [ ] Authorized field edits save and create audit history; quality, Follow-up State and Conversation status remain distinct.
- [ ] Manual import validates and previews errors without silently overwriting ambiguous identities; exports respect role scope and current filters.
- [ ] Phone filters are collapsed by default or compact enough that the first useful Lead entries remain visible.
- [ ] Verify empty, long-name, many-row, validation-error and restricted-access cases through the real APIs.

## Blocked by

- R02 (replace with the published GitHub issue reference after approval).
- R06 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
