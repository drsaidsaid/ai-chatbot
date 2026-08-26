# Inbox Conversation Cockpit

Status: Integration verification

## What to build

Redesign Inbox as the primary conversation workspace. The completed slice must
let a Human Operator select Hot, Review, and Booked queues, work a WhatsApp
conversation, inspect Summary/Evidence/Activity, confirm the AI Employee's next
step, assign ownership, pause/resume AI, and send replies or private notes from
one coherent cockpit.

## Reference screens

- Inbox desktop:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-6514bf72-f4ed-4b15-b614-5090c9c52ff7.png`
- Mobile Inbox:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-869a20f3-1a8d-4446-b097-f684e3072bc1.png`

## Acceptance criteria

- [x] Desktop Inbox matches the reference structure: app rail, conversation
      list with quick queues, center message workspace, compact Lead header,
      proposed next-step card, composer, and right Summary/Evidence/Activity
      panel.
- [x] Hot, Review, and Booked queue chips filter the conversation list in place
      and preserve the selected queue in URL/query state.
- [x] Conversation list search and filters support Lead Quality, Follow-up
      State, assignee, source, unanswered/review state, booking status, and
      message text where backed by existing search.
- [x] The conversation header shows Lead name, WhatsApp identity, phone,
      location when known, Lead Quality, Control State, assignee, booking state,
      and overflow actions from real conversation data.
- [x] Summary tab shows why the Lead matters, strongest evidence, missing
      signals, source, and next recommended action.
- [x] Evidence tab shows Qualification Evidence with source message,
      confidence/freshness where available, and superseded evidence state.
- [x] Activity tab shows AI decisions, handoff, assignment, pause/resume,
      booking, alert, delivery, and audit events in chronological order.
- [x] The proposed next-step card supports confirming a call time, assigning a
      Human Operator, pausing/resuming AI, opening technical details, and
      navigating to linked Knowledge or Test Center context when available.
- [x] Reply and Private note composer tabs are fully functional; private notes
      cannot be sent to a Lead, and WhatsApp reply mode uses the connected
      WhatsApp channel.
- [x] Every link, tab, form, filter, queue chip, dropdown, toggle, and action
      introduced or touched by the Inbox cockpit is keyboard-reachable, has a
      visible state, and routes or persists through existing Rails/Vue
      conventions.
- [x] Human reply, assignment, pause, resume, and resolution preserve the
      `control_version` safety behavior and block stale AI replies.
- [x] Mobile Inbox matches the mobile reference: top product header, queue chips,
      active conversation header, large touch-friendly message stream, bottom
      qualification/next-action card, composer, and bottom navigation.
- [x] Realistic data covers Highly Qualified booked/handoff, Qualified missing
      signals, Review-needed, follow-up due, AI active, Human active, paused,
      closed, empty queue, loading, and delivery-failure states.
- [x] Rails request/service specs cover any new summary/evidence/activity
      payloads, authorization, tenant scoping, and mutation side effects.
- [x] Vue component/store tests cover queue filters, tabs, composer modes,
      action disabled states, loading/error states, and long-message wrapping.
- [x] Codex in-app browser checks cover opening each queue, selecting a
      conversation, using Summary/Evidence/Activity tabs, starting a reply,
      pausing/resuming AI, and mobile bottom-card disclosure. No headless
      Chrome, Playwright CLI, or temporary browser script was used.
- [x] Same-viewport screenshots at 1487 x 1058 and 852 x 1846 are compared with
      the listed references and documented as faithful within the visual
      tolerances.
- [x] `docs/issues/011/design-qa.md` exists with `Result: Passed`, screenshots,
      viewport dimensions, zero-overlap notes, and accepted deviations.

## Blocked by

- Ticket 006: Conflict-free call booking.
- Ticket 007: Incomplete-lead follow-up and opt-out.
- Ticket 010: Conversation Cockpit navigation and responsive shell.
