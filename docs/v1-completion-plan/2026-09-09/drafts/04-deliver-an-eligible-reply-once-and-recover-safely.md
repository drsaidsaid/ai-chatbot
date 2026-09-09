# R04 — Deliver an eligible reply once and recover safely

Status: Draft for breakdown review; not published and not assigned.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/16

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Lead receives one eligible reply, and the Human Operator sees an honest delivery outcome.

## What to build

Repair the common outbound boundary from durable intent to provider result and inbox delivery status. Make concurrency, cancellation and uncertain provider outcomes explicit rather than allowing blind retries.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Two workers competing for one outgoing action cannot both dispatch it; claims have durable ownership and bounded recovery.
- [ ] Revalidate Control State/version, current permissions, launch state and recorded opt-out immediately before provider dispatch.
- [ ] Assignment, takeover, private/human reply, pause, closure and gate withdrawal invalidate pending automation as required by the product rules.
- [ ] Slow model work does not hold a conversation lock that prevents prompt human takeover.
- [ ] Crash and timeout paths distinguish failed, sent and uncertain acceptance; uncertain sends are reconciled or raised for review without automatic duplicate delivery.
- [ ] Intent creation and queue-enqueue failures are repaired by a real recovery path; the inbox shows accurate pending/canceled/failed/unknown outcomes.
- [ ] Verify competing-worker and crash cases across the canonical application boundary, not only sandbox decision labels.

## Blocked by

- R03 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
