# Conversation Cockpit Navigation and Responsive Shell

## What to build

Create the shared AI Lead Employee navigation and responsive shell that all
Conversation Cockpit surfaces use. The shell must live inside the existing
Chatwoot-derived dashboard, preserve account-scoped Rails/Vue route conventions,
and make Inbox, Leads, Bookings, Knowledge, Test Center, and Settings the only
primary V1 destinations.

Hot, Review, and Booked are Inbox quick queues. They must be reachable from
Inbox queue chips on desktop and mobile, not from the top-level sidebar.

## Reference screens

- Inbox desktop:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-6514bf72-f4ed-4b15-b614-5090c9c52ff7.png`
- Mobile Inbox:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-869a20f3-1a8d-4446-b097-f684e3072bc1.png`
- Any Settings reference for the settings subnav shell:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-e7660b52-ad00-49a5-b9cd-bedc50382d63.png`

## Acceptance criteria

- [x] Desktop primary navigation shows only Inbox, Leads, Bookings, Knowledge,
      Test Center, and Settings with the AI mark and Human Operator profile in
      the same regions as the references.
- [x] Mobile navigation shows Inbox, Leads, Bookings, and More; More contains
      working links to Knowledge, Test Center, and Settings.
- [x] Inbox exposes Hot, Review, and Booked as working quick queue chips with
      realistic counts sourced from the owned conversation/lead/review/booking
      data, not static UI constants.
- [x] Existing deep links for any previous Hot Leads or Reviews surface either
      redirect into the matching Inbox queue or remain hidden from ordinary V1
      users without breaking saved browser links.
- [x] Unsupported Community Edition surfaces remain hidden through navigation,
      permissions, policy, or feature gating without deleting broad CE source.
- [x] All routes are account-scoped with `frontendURL`/dashboard route
      conventions and enforce tenant membership on any backing Rails endpoint.
- [x] Settings uses an AI Lead Employee settings section sidebar with Offers &
      qualification, Booking & business hours, Team & assignment, Follow-ups,
      Alerts, and WhatsApp connection.
- [x] Every link, menu, tab, filter, form control, and toggle introduced or
      touched by this shell work is keyboard-reachable, has a visible state, and
      routes or persists through the existing Rails/Vue conventions.
- [x] Loading, empty account, permission-denied, small-screen, long label, and
      collapsed/expanded desktop sidebar states render without overlapping text
      or controls.
- [x] Vue route/sidebar tests cover active states, More navigation, hidden V1
      surfaces, and Inbox queue chip link generation.
- [x] Playwright checks cover desktop navigation at 1487 x 1058 and 1536 x 1024
      and mobile navigation at 852 x 1846 plus one narrow 390 px viewport.
- [x] Same-viewport screenshots are compared with the listed references and
      documented as faithful within the visual tolerances in
      `docs/specs/AI_LEAD_EMPLOYEE_CONVERSATION_COCKPIT_VISUAL_SPEC.md`.
- [x] `docs/issues/010/design-qa.md` exists with `Result: Passed`, captured
      screenshots, viewport dimensions, zero-overlap notes, and any accepted
      deviations.

## Blocked by

- Ticket 008: Operational dashboard and team access.
