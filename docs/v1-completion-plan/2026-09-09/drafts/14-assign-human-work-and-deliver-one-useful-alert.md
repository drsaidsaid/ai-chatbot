# R14 — Assign human work and deliver one useful Alert

Status: Draft for breakdown review; not published and not assigned.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/9

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

The right Human Operator receives a useful Alert and opens the specific work needing attention.

## What to build

Complete default-owner/manual assignment and per-type alert routes through Team & alerts settings and the shared messaging boundary.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Configure default owner and recipients for hot Lead, Booking, urgent Review Request and knowledge approval alerts in actual controls.
- [ ] Hot means a Highly Qualified Lead needing action, rather than every highly scored or already-handled Lead.
- [ ] Assignment/reassignment persists, creates audit history and refreshes authorized queues without bypassing human-control rules.
- [ ] Alerts include concise evidence, reason, owner and a deep link to the canonical Conversation, Booking or approval.
- [ ] Retries and repeated triggers do not send duplicate alerts; permitted delivery status/failure is visible with an actionable recovery path.
- [ ] Alerts disclose only data authorized for their recipient and respect applicable template/channel eligibility.
- [ ] Demonstrate a hot Lead and review/booking event through assignment, eligible delivery and opening the linked work.

## Blocked by

- R03 (replace with the published GitHub issue reference after approval).
- R04 (replace with the published GitHub issue reference after approval).
- R06 (replace with the published GitHub issue reference after approval).
- R09 (replace with the published GitHub issue reference after approval).
- R12 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
