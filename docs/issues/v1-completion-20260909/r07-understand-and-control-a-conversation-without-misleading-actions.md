# R07 — Understand and control a Conversation without misleading actions

Status: Implemented in the ticket branch; in-app browser acceptance is pending a normal Mac unlock.

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
- [x] A review request shows an answer/review action; booking fields appear only for an actual booking proposal. No fallback date is invented.
- [x] Take over, assign, pause, explicit resume and resolve produce persistent state changes and a visible outcome; unavailable actions explain why.
- [x] Public reply and private note have clear separate modes; internal content cannot enter outbound provider payloads.
- [x] Resume from human ownership follows the approved explicit-resume rule and permits only future eligible work, without releasing stale replies.
- [ ] Remove or implement inert More actions controls; secondary evidence and technical details do not crowd out messages.
- [ ] Demonstrate the complete keyboard and phone journey with delayed-AI cancellation, not screenshots alone.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/19 (R02).
- https://github.com/drsaidsaid/ai-chatbot/issues/21 (R04).
- https://github.com/drsaidsaid/ai-chatbot/issues/22 (R05).
- https://github.com/drsaidsaid/ai-chatbot/issues/23 (R06).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.

## Implementation evidence

The ticket branch implements automated coverage for the first six criteria. A production
build completed for the prior immutable source candidate, and an isolated synthetic
runtime was prepared without provider credentials or outbound traffic. Independent
review then required durable handoff recovery and false-enqueue handling. Those
corrections pass the final automated checks and both final reviews, while their
normal commit hooks left the reviewed tree unchanged and the exact-source
production build passed. The
in-app browser could not be used because the host reported that the Mac was
locked and automatic unlock failed. The final criterion remains open until the
final source candidate completes the required desktop, phone and keyboard walk.
The first and sixth criteria remain unchecked because their readability and
visual-priority clauses require that browser evidence.

See `docs/releases/2026-09-11-r07/README.md` for the checks, fixture boundaries,
restart procedure and exact browser blocker.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
