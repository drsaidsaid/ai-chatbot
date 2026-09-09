# R07 — Understand and control a Conversation without misleading actions

Status: Draft for breakdown review; not published and not assigned.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/13

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Human Operator can read the conversation, take over, reply privately or publicly, and explicitly hand control back.

## What to build

Redesign the Conversation around readable identity, messages and one relevant next action. Wire all exposed controls through the existing authority and delivery boundaries.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Name, one phone number, current AI/Human control and assignee stay visible and readable on desktop and phone.
- [ ] A review request shows an answer/review action; booking fields appear only for an actual booking proposal. No fallback date is invented.
- [ ] Take over, assign, pause, explicit resume and resolve produce persistent state changes and a visible outcome; unavailable actions explain why.
- [ ] Public reply and private note have clear separate modes; internal content cannot enter outbound provider payloads.
- [ ] Resume from human ownership follows the approved explicit-resume rule and permits only future eligible work, without releasing stale replies.
- [ ] Remove or implement inert More actions controls; secondary evidence and technical details do not crowd out messages.
- [ ] Demonstrate the complete keyboard and phone journey with delayed-AI cancellation, not screenshots alone.

## Blocked by

- R02 (replace with the published GitHub issue reference after approval).
- R04 (replace with the published GitHub issue reference after approval).
- R05 (replace with the published GitHub issue reference after approval).
- R06 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
