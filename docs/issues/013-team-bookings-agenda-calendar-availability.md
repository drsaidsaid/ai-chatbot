# Team Bookings Agenda, Calendar, and Availability

Status: Integration verification

## What to build

Create Bookings as the authoritative team agenda, calendar, and availability
workspace. The completed slice must let Human Operators review confirmed and
pending bookings, inspect preparation context, reschedule or cancel safely, and
verify the same availability rules used by the AI Employee booking flow.

## Reference screen

- Team Bookings:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-18bd727f-32ef-4b60-9c49-48bc316d892b.png`

## Acceptance criteria

- [x] Bookings top-level navigation opens a workspace with working Agenda,
      Calendar, and Availability tabs.
- [x] Agenda includes Today, previous/next range, current week label, team
      capacity meter, team member filter, booking status filter, Offer filter,
      timezone filter, and more filters.
- [x] Agenda rows are grouped by date and show time, Lead, business, assigned
      Human Operator, call type, WhatsApp confirmation, calendar state, and
      preparation status.
- [x] Selecting a Booking opens a right detail panel with Booking details, Offer,
      status, booked channel, created time, assignee, meeting link, calendar
      invite state, preparation brief, strongest evidence, likely objection,
      suggested opening question, and actions.
- [x] Reschedule updates the Booking, calendar provider state, WhatsApp
      confirmation state, alerts, Follow-up State, and audit history without
      duplicate side effects.
- [x] Cancel booking requires confirmation and updates calendar provider state,
      WhatsApp notification state, alerts, Follow-up State, and audit history.
- [x] Calendar tab provides a week/day view of the same booking records and
      indicates conflicts, awaiting confirmation, no invite, ready, in progress,
      and not started states.
- [x] Availability tab shows the actual available slots produced from connected
      calendar availability, Business Account hours, booking type rules, buffers,
      minimum notice, and assignment settings.
- [x] Every link, tab, form, filter, dropdown, toggle, date control, and action
      introduced or touched by Bookings is keyboard-reachable, has a visible
      state, and routes or persists through existing Rails/Vue conventions.
- [x] Realistic states include confirmed WhatsApp/calendar, awaiting WhatsApp,
      Google confirmed, Google invited, calendar conflict, no invite, ready prep,
      in-progress prep, not-started prep, no bookings, and failed provider load.
- [x] Rails request/service specs cover listing, filtering, reschedule, cancel,
      idempotent provider mutations, tenant scoping, and authorization.
- [x] Vue tests cover tabs, filters, date controls, selected detail panel,
      reschedule/cancel dialogs, status badges, loading/error states, and
      overflow handling.
- [x] Playwright checks cover Agenda, Calendar, Availability, filtering,
      selecting a booking, rescheduling, cancelling, opening the conversation,
      and mobile access from the bottom nav.
- [x] A same-viewport screenshot at 1487 x 1058 is compared with the reference
      and documented as faithful within the visual tolerances; mobile behavior
      is checked at 852 x 1846 and 390 px widths.
- [x] `docs/issues/013/design-qa.md` exists with `Result: Passed`, screenshots,
      viewport dimensions, zero-overlap notes, and accepted deviations.

## Completion evidence

- Implementation branch: `codex/ticket-013-team-bookings-agenda-calendar-availability`
- Design QA: `docs/issues/013/design-qa.md`
- Desktop browser report: `docs/issues/013/screenshots/desktop-bookings-browser-qa.json`
- Desktop comparison: `docs/issues/013/screenshots/reference-vs-app-desktop-1487x1058.png`
- Mobile reports:
  `docs/issues/013/screenshots/mobile-bookings-390x844-browser-qa.json`,
  `docs/issues/013/screenshots/mobile-bookings-852x1846-browser-qa.json`
- Final verification: focused Rails specs, Ruby lint, focused Vue tests,
  frontend lint, locale validation, production Vite build, and full diff review
  passed.

## Blocked by

- Ticket 006: Conflict-free call booking.
- Ticket 010: Conversation Cockpit navigation and responsive shell.
