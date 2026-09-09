# Approved V1 navigation

Status: Approved as part of the 18-ticket execution instruction on 9 September 2026.

## Five primary destinations

| Destination | What belongs here | What does not need its own primary menu item |
|---|---|---|
| Inbox | Conversations, replies, private notes, human control, assignment; All, Needs review and Hot leads views | Hot leads and customer Review Requests are views of the same work, not separate applications |
| Leads | Lead directory, qualification evidence, permitted edits/import/export and compact business overview | A second generic Contacts area or broad Reports suite |
| Bookings | Agenda and optional Calendar view of the same reservations; booking details, reschedule/cancel | A separate homepage for already-booked conversations |
| Knowledge | Documents, Answers and clearly labeled Drafts & approvals | Customer Review Requests mixed with knowledge maintenance |
| Settings | Business & offers; Team & alerts; Booking hours; Follow-ups; WhatsApp connection; AI & testing | Full Test Center as an everyday operator destination; generic Open inboxes detours |

Keep all five accessible on desktop. On phones, keep Inbox, Leads, Bookings and More, with Knowledge and Settings inside More. The important fix is maintaining a complete path to every allowed destination and back; phone users should not face a vanished list or settings menu.

## Changes tied to the audit

| Current navigation or control | Why it confuses or adds work | Proposed treatment | Evidence |
|---|---|---|---|
| Full Test Center in primary navigation | It has equal prominence with daily conversation work although it is chiefly an administrator setup/release task | Move to Settings → AI & testing; retain Try this answer/document shortcuts that deep-link to the same testing system | Screens 13–14, 23 |
| Inbox Review and Knowledge Needs Review | Both can lead to customer review requests, while knowledge approval is a different responsibility | Customer request resolution lives in Inbox → Needs review. Knowledge → Drafts & approvals handles reusable content. Link related records without duplicating queues | Screens 04, 12 |
| Hot/Review/Booked quick queues and an Urgent dropdown | Labels overlap; a booked Conversation is not necessarily urgent or awaiting human work | Keep All, Needs review and Hot leads as clear Inbox views; retain Booked and Follow-up due as optional filters/saved views | Screens 03–04 |
| Booked queue alongside Bookings | Useful as a filter, but can look like a competing booking workspace | Keep Bookings as the authoritative reservation workspace; the Inbox filter opens conversations and links to their booking | Screens 03, 07 |
| Availability inside Bookings and Booking/business-hours Settings | Seeing available slots and editing the rules have unclear ownership | Put editable rules and their preview in Settings → Booking hours; provide a shortcut from Bookings. Preserve slot selection during booking | Screens 08, 16 |
| Team assignment, Alerts and WhatsApp pages that only say Open teams/Open inboxes | These intermediate screens require another click and reveal generic administration unrelated to the chosen task | Open the actual Team/Alert or WhatsApp controls within one persistent Settings layout | Screens 17, 19–21 |
| Add Inbox shows Website, SMS, Email, API, Telegram, Line and more | These routes suggest capabilities outside the documented one-number WhatsApp V1 | Direct WhatsApp setup only for V1; gate other setup paths while retaining CE source | Screen 22 |
| Settings navigation disappears on phone or after opening provider/inbox setup | The user loses the path to sibling settings | Persistent section selection on all Settings routes; phone uses an accessible section picker/list | Screens 21, 23, 29 |
| More actions button without an action | It promises navigation or choices that do not exist | Implement only useful actions or remove the control until available | Screen 04 and supporting source verification |
| Separate generic contacts, macros, campaigns, help center and broad reports | They are outside the chosen V1 scope and may suggest unsupported workflows | Keep them gated; audit direct routes too. Add compact required business metrics inside the existing workspace | Approved V1 scope; these other screens were not all visited in the UI audit |

## Keep useful distinctions

Inbox answers “Who needs a reply or decision now?” Leads answers “What do we know about this person?” Bookings answers “Which calls are actually reserved?” These are distinct tasks, so combining all three into one large dashboard would increase crowding.

Agenda and Calendar are two useful views of the same bookings and need not be removed. Similarly, a test shortcut beside an answer is useful when it opens the same testing experience and preserves context. Redundancy is a problem when state or responsibility is duplicated, not simply when a useful destination has two entry points.

## Rules for implementation

- Preserve the Community Edition Rails/Vue application and its existing component conventions; do not build a parallel production shell.
- Display only actions a role may use, and enforce the same permissions on the server.
- Preserve existing supported deep links through redirects into the canonical destination; do not silently route a user to the wrong record.
- Use permanent labels and readable selected states. Browser back, refresh, keyboard navigation and phone return-to-list must work.
- Match the primary action to the current task. Resolve review must not create a booking; an internal note must not send a customer reply.
- Let optional filters and detail panes yield space to names, messages and actual work.
- Keep the standalone app free of hard-coded Online Profits identity or workflows.

## First visible deliverable

A working local Inbox path with the new menu, readable lead identity, clear AI/Human control and a complete phone list → conversation → list journey. Prepare the desktop and phone visual reference, implement in the existing product, and inspect it in the in-app browser before applying the same treatment across Leads, Knowledge, Bookings and Settings.

This document is a navigation specification, not a generated mockup or an implemented redesign.
