# R02 — Sign in and navigate the simplified app on desktop and phone

Status: Locally complete; awaiting coordinator review and integration. Based on R01-integrated baseline `fb7d54ac3c527940a63b171c45e4e2e7ca898d26`. GitHub #19 remains open.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/13

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Human Operator can enter the app, reach each permitted work area and return to a conversation list.

## What to build

Deliver the five-item navigation and first complete Inbox navigation path in the owned application. Use this path to establish the visual treatment for page titles, spacing, typography, controls and focus. Prepare desktop and phone visual references before expanding the treatment to the other screens.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [x] Primary navigation contains Inbox, Leads, Bookings, Knowledge and Settings; full Test Center is reachable under Settings → AI & testing for authorized administrators.
- [x] Use one AI Lead Employee identity from login through the app; remove hard-coded Online Profits sample copy from standalone defaults while retaining license attribution.
- [x] Inbox has clearly named views for all conversations, Needs review and Hot leads; secondary filters retain follow-up and booked-conversation use cases.
- [x] At 390px, the normal in-app width and desktop widths, opening a conversation and Back to list returns to the same selectable queue with filters preserved.
- [x] Every supported Settings section remains reachable on phones; browser back, direct links and refresh retain valid navigation state.
- [x] Gate unsupported V1 channel setup and public routes according to existing permissions; retain underlying CE source.
- [x] Demonstrate this complete path in the in-app browser, with readable lead identity, visible focus and correctly named controls; document the visual reference used.

Local acceptance evidence: [R02 release record](../../releases/2026-09-09-r02/README.md), including screenshots, checks, source hashes and successor handoff. Production delivery and the stronger R06 member scope are not implied by these local checks.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/18 (R01).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
