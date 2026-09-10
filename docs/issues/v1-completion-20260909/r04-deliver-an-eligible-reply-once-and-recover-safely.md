# R04 — Deliver an eligible reply once and recover safely

Status: Backend and component acceptance verified; in-app browser acceptance pending.
Implemented from integrated R03 baseline
`f2b184e1c332f0bf68c31dec460f7e5599657a72`; R03 accepted by the coordinator.

Decision: [ADR 0011](../../adr/0011-owned-whatsapp-outbound-delivery.md).
Acceptance seams: canonical Rails jobs/message APIs, independent database and
process workers, isolated fake provider HTTP, and the existing Inbox UI.
Browser validation awaits the coordinator's allocation. No live assets or launch
approval are implied. Issue remains open until integration verification.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/16

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Lead receives one eligible reply, and the Human Operator sees an honest delivery outcome.

## What to build

Repair the common outbound boundary from durable intent to provider result and inbox delivery status. Make concurrency, cancellation and uncertain provider outcomes explicit rather than allowing blind retries.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [x] Two workers competing for one outgoing action cannot both dispatch it; claims have durable ownership and bounded recovery.
- [x] Revalidate Control State/version, current permissions, launch state and recorded opt-out immediately before provider dispatch.
- [x] Assignment, takeover, private/human reply, pause, closure and gate withdrawal invalidate pending automation as required by the product rules.
- [x] Slow model work does not hold a conversation lock that prevents prompt human takeover.
- [x] Crash and timeout paths distinguish failed, sent and uncertain acceptance; uncertain sends are reconciled or raised for review without automatic duplicate delivery.
- [ ] Intent creation and queue-enqueue failures are repaired by a real recovery path; the inbox shows accurate pending/canceled/failed/unknown outcomes.
- [x] Verify competing-worker and crash cases across the canonical application boundary, not only sandbox decision labels.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/20 (R03).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.

## Implementation evidence

See [R04 release evidence](../../releases/2026-09-10-r04/README.md).
The remaining Inbox criterion has verified API and Vue component checks, plus
seeded local display fixtures. Real desktop/phone in-app interaction, reload
persistence and an operator-created send through the running Rails sender to
the loopback provider remain pending the coordinator's browser allocation.
#21 remains open and unintegrated until that acceptance is complete.

Coordinator follow-up scope: correct local payload preparation versus dispatch
uncertainty, accepted-before-receipt display/evidence, and originating review
rejection serialization. Include the reachable booking cancel/reschedule notice
bypass: atomically record one operator-authored Message per mutation identity and
use shared dispatch/recovery. Broader calendar/rescheduling correctness remains
blocked R13 work. Follow-up red/green and rereview evidence is recorded in the
release directory. The final receipt correction also reserves client aliases
that normalize to delivery/receipt/echo fields; actual HTTP responses feed the
Inbox transform and MessageMeta regression, preserving ordinary attributes and
trusted provider ingress. Browser acceptance remains pending.
