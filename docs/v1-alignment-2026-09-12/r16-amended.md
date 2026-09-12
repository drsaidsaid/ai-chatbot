# R16 — See trustworthy basic business results without another main menu

Status: Approved for implementation; blocked by the issues below.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/13

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can see whether Leads are being answered, qualified and booked without opening a generic reporting suite.

## What to build

Add a compact business overview within the existing Lead/Inbox workspace, using defined account-scoped metrics and links to the underlying records.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Define and verify totals, Lead Quality distribution, highly qualified Leads, Review Requests, Bookings and qualification-to-booking conversion for a selected period.
- [ ] Where required by the PRD, include source quality, first-response time and human takeover rate with explicit denominators and timestamp rules.
- [ ] Counts, filters and drill-down results agree; avoid counting duplicate events or conflating Lead Quality with Follow-up State.
- [ ] Unknown, unmeasured and zero are distinct; no fabricated trend or inferred success from missing data.
- [ ] Admin-only business summaries and exports enforce server permissions; Team Members see only documented permitted data.
- [ ] Keep generic CE Reports hidden and avoid a sixth primary navigation item; record this scope distinction in the product documents.
- [ ] Verify known fixtures with duplicate events, empty periods and bookings that are canceled/rescheduled.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/23 (R06).
- https://github.com/drsaidsaid/ai-chatbot/issues/25 (R08).
- https://github.com/drsaidsaid/ai-chatbot/issues/26 (R09).
- https://github.com/drsaidsaid/ai-chatbot/issues/30 (R13).
- https://github.com/drsaidsaid/ai-chatbot/issues/31 (R14).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of the amended V1 completion programme in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.


## Approved 12 September product amendment

These criteria supersede conflicting earlier wording. Follow ADR 0016 and the approved product agreement. Existing evidence remains historical; verify the revised contract before acceptance.

- [ ] Show business fit separately from readiness and follow-up state; disabled qualification is not a rejected Lead.
- [ ] Client Billing shows AI allowance and separately labelled Meta messaging costs; platform-only views show subscription revenue, actual AI costs, missing cost records and estimated contribution margin. Never expose another Business Account’s data or provider keys. R23/R24 own underlying financial truth.
- [ ] Broadcast results use actual delivery states and estimates clearly marked; no unsupported attribution of revenue or sales.

### Additional blockers

- https://github.com/drsaidsaid/ai-chatbot/issues/39
- https://github.com/drsaidsaid/ai-chatbot/issues/40
- https://github.com/drsaidsaid/ai-chatbot/issues/43
