# R12 — Resolve a Review Request and optionally propose knowledge

Status: Draft for breakdown review; not published and not assigned.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/17

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Human Operator can answer one Lead or record a private resolution, then separately propose a reusable answer.

## What to build

Give customer Review Requests one operational home in Inbox → Needs review. Keep knowledge maintenance in Knowledge → Approvals, with linked records and separate actions.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] One Review Request appears with reason, assigned owner, source question and conversation link; duplicate incoming events do not multiply it.
- [ ] Send reply and resolve is distinct from Save internal note/resolve; the user sees the recipient and exact effect before submission.
- [ ] Propose as reusable answer is an explicit separate choice, not checked by default when resolving an internal note.
- [ ] Proposed knowledge records its Offer/category/source but remains unavailable until an authorized administrator approves it.
- [ ] Resolving, sending and proposing are idempotent/recoverable; partial failure shows what succeeded and what still needs attention.
- [ ] Old review links open the canonical request in Inbox, while approval links open the linked Knowledge proposal.
- [ ] Demonstrate a refund review from incoming question through human resolution, optional approval and a future grounded answer.

## Blocked by

- R07 (replace with the published GitHub issue reference after approval).
- R11 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
