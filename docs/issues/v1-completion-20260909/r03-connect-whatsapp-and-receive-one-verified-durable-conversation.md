# R03 — Connect WhatsApp and receive one verified durable conversation

Status: Implemented and locally verified from integrated R01/R02
`5577a37ddae5f6d08b33b0b33aefe6d933d7003c`; awaiting coordinator integration.
GitHub #20 remains open.

Evidence and R04 handoff: [R03 release proof](../../releases/2026-09-10-r03/README.md).

Implementation decision: [ADR 0009](../../adr/0009-verified-whatsapp-receipts-and-recovery.md).
Approved test boundaries: administrator connection API and Settings UI; canonical
signed webhook through persisted Conversations; real database concurrent replay
and crash/queue recovery; immutable delivery history and status projection.
R01/R02 blockers were integrated and verified by the coordinator on 10 September.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/16

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can connect the Business Account's WhatsApp number and know whether an incoming message was accepted.

## What to build

Replace the generic inbox detour with a direct WhatsApp setup and health path. Persist authenticated incoming receipts before processing; correctly normalize all entries and delivery updates into the owned inbox.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [x] One direct Meta WhatsApp connection per Business Account; setup has actual connection controls, saved state and actionable health information.
- [x] All supported setup paths reject invalid or missing message signatures; incomplete signing configuration cannot be presented as ready.
- [x] Credentials are encrypted appropriately and responses expose safe status fields instead of stored secrets; setup still works after removing credential reflection.
- [x] Multi-entry, multi-change and multi-sender batches produce all expected conversations/messages with correct Business Account routing.
- [x] Duplicate receipts and crashes between receipt, normalization and queue creation recover without lost or duplicate logical messages.
- [x] Delivery updates do not regress a delivered/read state when older updates arrive; errors have safe user-facing recovery actions.
- [x] Exercise the canonical route with an isolated fake provider; later real test delivery requires authorized test assets.

## Resolved blockers

- https://github.com/drsaidsaid/ai-chatbot/issues/18 (R01).
- https://github.com/drsaidsaid/ai-chatbot/issues/19 (R02).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
