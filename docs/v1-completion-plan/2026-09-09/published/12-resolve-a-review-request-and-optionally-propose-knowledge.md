# R12 — Resolve a Review Request and optionally propose knowledge

Status: Approved for implementation; blocked by the issues below.

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

- https://github.com/drsaidsaid/ai-chatbot/issues/24 (R07).
- https://github.com/drsaidsaid/ai-chatbot/issues/28 (R11).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
