# R16 — See trustworthy basic business results without another main menu

Status: Draft for breakdown review; not published and not assigned.

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

- R06 (replace with the published GitHub issue reference after approval).
- R08 (replace with the published GitHub issue reference after approval).
- R09 (replace with the published GitHub issue reference after approval).
- R13 (replace with the published GitHub issue reference after approval).
- R14 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
