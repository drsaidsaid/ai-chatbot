# R03 — Connect WhatsApp and receive one verified durable conversation

Status: Draft for breakdown review; not published and not assigned.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/16

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can connect the Business Account's WhatsApp number and know whether an incoming message was accepted.

## What to build

Replace the generic inbox detour with a direct WhatsApp setup and health path. Persist authenticated incoming receipts before processing; correctly normalize all entries and delivery updates into the owned inbox.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] One direct Meta WhatsApp connection per Business Account; setup has actual connection controls, saved state and actionable health information.
- [ ] All supported setup paths reject invalid or missing message signatures; incomplete signing configuration cannot be presented as ready.
- [ ] Credentials are encrypted appropriately and responses expose safe status fields instead of stored secrets; setup still works after removing credential reflection.
- [ ] Multi-entry, multi-change and multi-sender batches produce all expected conversations/messages with correct Business Account routing.
- [ ] Duplicate receipts and crashes between receipt, normalization and queue creation recover without lost or duplicate logical messages.
- [ ] Delivery updates do not regress a delivered/read state when older updates arrive; errors have safe user-facing recovery actions.
- [ ] Exercise the canonical route with an isolated fake provider; later real test delivery requires authorized test assets.

## Blocked by

- R01 (replace with the published GitHub issue reference after approval).
- R02 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
