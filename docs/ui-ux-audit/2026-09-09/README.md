# AI Lead Employee UI/UX audit

**Overall: 4.5/10. Appearance: 4/10. Ease of use: 5/10.**

The app has a useful foundation, but it does not yet feel like a finished product. Some screens are crowded while others have large unused areas. Important names and actions get squeezed. A few controls lead to the wrong action or a dead end. A focused UI/UX improvement phase should be part of standalone V1.

These are judgment scores, not measured customer satisfaction or percentages of code completion. The overall score gives appearance and ease of use equal weight. On this scale, 5 means usable with substantial friction; 8 means a polished, dependable V1. Phone behavior is included in ease of use.

## What I reviewed

The latest locally available release candidate, commit `74d156e327e3ddb2deedd1503c6d1c04b0b1359e`, in the **Codex in-app browser** on 9 September 2026. Desktop was checked at 1440 × 1000, phone at 390 × 844, and the normal in-app view at 772 × 695.

The app ran from an isolated copy with seven example leads, three approved answers, one draft answer, two documents, one review request, and one example booking. External provider traffic was blocked. No real messages, bookings, approvals, or provider connections were made. The original application code was not changed. A VPS deployment was not verified.

[Open the complete screenshot walkthrough](./screenshots.md). All 29 screenshots were captured during this audit in the in-app browser, saved, and visually inspected. [Capture notes](./capture-notes.json) record the individual states.

## Screen-by-screen result

“Needs work” means the task is understandable but has notable problems. “Poor” means substantial confusion or an unusable part of the path.

| Step | What was reviewed | Health | Evidence |
|---|---|---|---|
| 1 | Sign in and product identity | Needs work | 01 |
| 2 | Desktop inbox, conversation, Hot/Review queues and lead brief | Poor | 02–04 |
| 3 | Lead list, search, selected profile and no-results state | Needs work | 05–06 |
| 4 | Booking agenda, selected booking and unavailable-calendar state | Needs work | 07–08 |
| 5 | Knowledge document editor and AI access explanation | Needs work | 09 |
| 6 | Approved answers, draft status and required-field validation | Needs work | 10–11 |
| 7 | Resolve a knowledge review request | Poor | 12 |
| 8 | Test scenarios and release-readiness screen | Needs work | 13–14 |
| 9 | Qualification, business hours and follow-up settings | Poor | 15–16, 18 |
| 10 | Team/alert setup entries and WhatsApp setup path | Poor | 17, 19–22 |
| 11 | AI provider setup entry | Needs work | 23 |
| 12 | Phone conversations, return to list, leads, bookings and settings | Poor | 24–29 |

## What is already good

- The six main navigation choices are easy to understand.
- Hot, Review and Booked queues give useful ways to prioritize work. Changing from Hot to Review selected the appropriate example lead.
- Lead search returned the right person. A search with no match correctly said “No leads match these filters.”
- Knowledge separates documents, approved answers and review requests. Its explanation of sensitive topics is helpful.
- Required-field validation focused the empty answer title, and a visible focus ring appeared.
- Test Center clearly says simulations do not send messages. Release approval is visibly locked before requirements are met.
- Phone lead and booking entries become cards instead of forcing the desktop table onto a narrow screen.

## Fix before V1

### 1. Restore the phone navigation paths

**Steps 2 and 12; screenshots 24–29. High priority.**

On a phone, “Back to list” produced “Select a conversation” without any conversation list. Settings showed “Offers and qualification” but no way to choose the other settings sections. The Save changes label also wrapped and clipped.

The source supports both observations: the inbox list stays hidden below the large-screen breakpoint, and the settings section navigation stays hidden below the medium-screen breakpoint without a replacement.

**Required result:** returning from a conversation shows a selectable list; every supported settings section remains reachable on a phone; primary buttons remain fully readable. Verify the same paths at phone, tablet and desktop widths.

### 2. Make the proposed action match the actual task

**Step 2; screenshots 03–04. High priority.**

A refund question in the Review queue showed “Answer Review,” but its main button was “Confirm call time.” The question itself appeared under “Proposed time.” The source renders these booking fields and the booking button for this action card regardless of the action type.

The booking handler also supplies a time one day ahead if no booking exists. That source behavior was inspected; the button was not submitted during this audit.

**Required result:** review requests lead to answering or assigning a review; bookings lead to reviewing a specific proposed time. Never invent a time behind a generic confirmation button. Use one clear primary action and show the result of taking it.

### 3. Make human control obvious

**Steps 2 and 12; screenshots 03–04 and 24–25. High priority.**

Desktop shows Human Active, but Resume AI is disabled without an explanation. The code explicitly prevents resuming from human_active in this control. On the phone, the current controller and assignee are absent even in the expanded brief. The desktop More actions button showed no response; its source has no click handler.

**Required result:** always show who is handling the conversation. Provide clear, usable take-over and hand-back actions with plain explanations when an action is unavailable. Remove inert controls until they work. This audit does not prove the backend takeover protections work.

### 4. Separate a private resolution from sending a customer reply

**Step 7; screenshot 12. High priority.**

The review answer box invites either an answer or an internal resolution note. “Send answer to Lead” and “Propose as Approved Answer” are both checked by default, while the button only says “Resolve.”

**Required result:** distinguish “Send reply and resolve” from “Save internal note.” Make proposing reusable knowledge a separate, explicit choice. Show the recipient and the exact effect before submission. No reply was sent in this audit.

### 5. Give the main work more room

**Steps 2, 3, 8 and 12; screenshots 03–05, 13, 27–28. High priority.**

At 1440px, the conversation header squeezes the lead's name out of view. The lead table truncates names, assignees, source and next action. Test Center gives a large blank transcript panel half the screen while scenario descriptions wrap into very narrow columns. On the phone lead list, headers and expanded filters leave only part of the first lead visible.

**Required result:** protect space for the person's name, latest message and next action. Open secondary detail panels on demand. Collapse optional filters by default on phones. Let empty transcript panels yield space to the scenario list. Remove duplicate phone-number text and unnecessary repeated summaries.

### 6. Finish the business settings

**Steps 9–11; screenshots 15–23. High priority.**

The budget field shows 20000000 beneath a TZS 200,000–500,000 label because it directly edits stored cents. The page named Offers and qualification has no visible offer management. Follow-up delay is shown as 1440 minutes without a plain summary or preview. Business hours has a free-text timezone and no visible weekday/exception controls.

Team assignment, Alerts and WhatsApp connection are intermediate pages pointing into generic workspace settings. Opening AI provider or inbox settings removes the settings section navigation. WhatsApp setup exposes Website, SMS, Email, API, Telegram and Line despite the documented WhatsApp-only V1 scope.

**Required result:** show money in the currency people use, readable time units, and a preview of what each rule means. Keep a consistent settings layout. Give each setting its actual controls or a clear scoped path to them. Gate unsupported V1 channels while retaining the Community Edition source.

### 7. Use one product identity and one visual system

**Steps 1, 5 and 10–11; screenshots 01, 09, 17, 19–23. High priority for the requested visual quality.**

Login shows the Chatwoot logo above AI Lead Employee. Settings mentions Chatwoot account configuration. A default document test question names Online Profits inside the standalone example account. Pages vary in title position, padding, card borders, table spacing, button treatment and where navigation appears.

**Required result:** a consistent AI Lead Employee identity, page header, spacing scale, type hierarchy, form treatment and action placement. Use the existing Rails/Vue Community Edition components and design tokens. Preserve the required MIT attribution; replacing user-facing branding does not mean removing the license notice. Avoid hard-coded Online Profits wording in the standalone app.

### 8. Explain missing data and failures honestly

**Steps 4 and 8; screenshots 08 and 13–14. Medium priority.**

Availability displays both “Failed provider load” and “No available slots match these rules,” with no visible retry/connect guidance. In this isolated environment, a provider failure is expected; the finding is about the explanation, not proof of a production provider outage.

Release check shows 0% safety failures before any tests were run, alongside “Not enough data” for other metrics. Its lower blocking-check text contains machine identifiers such as stale_ai_job.

**Required result:** distinguish “we could not check” from “there are no slots.” Explain the next step. Show “Not tested” when there is no evidence, include sample counts, and replace machine identifiers with readable names and links to the relevant check.

### 9. Clarify draft and approval states

**Steps 5–7; screenshots 09–12. Medium priority.**

Approved Answers includes a draft item, and its detail labels the draft content “Approved answer.” The document editor shows status selection, Save draft, Publish changes and access switches together without a concise statement of what is currently live. New-answer fields rely on placeholders for visible labels.

**Required result:** state “Draft — not used by AI” versus “Published — used by AI” explicitly. Keep permanent field labels. Make saving, publishing and approving distinct, predictable steps. Backend approval enforcement was outside this UI audit.

## Accessibility findings

This was a targeted inspection, not a complete accessibility certification.

- **Confirmed contrast problem:** the enabled Save changes button uses white 14px text on rgb(39,129,246), approximately **3.78:1**. This is below the 4.5:1 minimum for normal text in [W3C's contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). Disabled controls were not counted as contrast failures.
- **Missing names:** desktop lead filters have no associated labels or aria-labels in the rendered DOM. Mobile Import/Export and several conversation/inbox icon buttons appeared unnamed in the accessibility tree.
- **Keyboard selection gap:** desktop lead rows are clickable but have no tabindex or keyboard handler. Their named checkboxes operate bulk selection rather than opening the selected lead. A keyboard equivalent should be provided.
- **Reflow problems:** the phone dead ends and clipped Save changes label are confirmed. A 390px document width matched the 390px viewport, so lack of whole-page overflow does not mean the interface works at that size.
- **Strengths:** named main navigation, several named form inputs and action buttons, text labels alongside colored status badges, a visible input focus ring, and native required-field validation.
- **Still to verify:** full keyboard journeys, screen-reader announcements, every contrast pair, 200%/400% zoom, real touch targets with spacing, virtual keyboard behavior, dark mode and assistive technology use.

[Rendered DOM observations](./accessibility-dom.json) and [source verification](./source-verification.md) provide supporting detail.

## Recommended sequence

1. Repair navigation dead ends, misleading actions, human control and reply-versus-note choices.
2. Simplify the inbox, lead list and Test Center layouts across desktop and phone.
3. Apply the consistent branding, typography, spacing, buttons and forms.
4. Complete readable business settings, connection guidance and honest empty/error states.
5. Verify the main operator journeys with representative users, keyboard use and real devices.

Before calling the design ready for V1, an operator should be able to find a lead, understand the next action, take over, resolve a question, manage a booking and reach every setting without a dead end or misleading control. Important names and buttons must remain readable at each supported size.

## Evidence limits

This report assesses the inspected release candidate and fixture states. It does not establish end-to-end WhatsApp delivery, calendar integration, AI answer quality, load performance, role permissions or production readiness. Those belong to the separate functional audit.

Example conversation prose and the synthetic booking were created with different timezone assumptions; their visible time discrepancy is excluded from product findings. Synthetic qualification evidence, missing business fields and booking ownership were not treated as proof of AI or data extraction failures. Apparent repeated messages after navigation were not investigated enough to score as a confirmed defect.

No tickets were created yet, in keeping with the request to receive the UI/UX audit first. These findings can be combined with the standalone V1 gaps using Matt Pocock's to-issues workflow.
