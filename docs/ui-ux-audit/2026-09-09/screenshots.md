# Screenshot walkthrough

[Read the simple audit and priorities](./README.md). All captures are from the in-app browser during this audit. Example people and messages are synthetic. Desktop: 1440 × 1000. Phone: 390 × 844. Captures 01–02: 772 × 695.

## Screenshot 01-login · Step 1

In-app browser, fresh default RC installation. Chatwoot wordmark conflicts with product heading.

![01-login](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/01-login.jpg)

## Screenshot 02-conversation-tablet · Step 2

Default in-app viewport 772×695: mobile shell; message area compressed between navigation and composer.

![02-conversation-tablet](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/02-conversation-tablet.jpg)

## Screenshot 03-conversation-desktop · Step 2

Desktop breakpoint test at 1440×1000, synthetic booked lead selected.

![03-conversation-desktop](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/03-conversation-desktop.jpg)

## Screenshot 04-review-conversation · Step 2

Review queue selects correct lead, but answer-review card shows Proposed time filled with refund question and Confirm call time CTA. Verify source versus fixture.

![04-review-conversation](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/04-review-conversation.jpg)

## Screenshot 05-leads · Step 3

Lead list, populated synthetic account. Inspect hierarchy, search and filter discoverability.

![05-leads](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/05-leads.jpg)

## Screenshot 06-leads-empty · Step 3

Search correctly returns No leads match these filters. Visible focus ring and clear icon; no prominent reset-all action; empty detail pane remains.

![06-leads-empty](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/06-leads-empty.jpg)

## Screenshot 07-bookings · Step 4

Synthetic booking list and detail. Any date difference against conversation prose is fixture inconsistency, excluded from app findings.

![07-bookings](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/07-bookings.jpg)

## Screenshot 08-availability · Step 4

Disconnected-provider state: Failed provider load and No available slots displayed together, with no visible connect/retry guidance. Failure expected under isolated environment; recovery UX assessed only.

![08-availability](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/08-availability.jpg)

## Screenshot 09-knowledge · Step 5

Document editor with distinct Documents, Approved Answers and Needs Review tabs. Helpful sensitive-topic explanation. Save/publish/status/access toggles compete; default test prompt mentions Online Profits in standalone workspace.

![09-knowledge](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/09-knowledge.jpg)

## Screenshot 10-approved-answers · Step 6

Draft item appears under Approved Answers; detail labels draft text Approved answer. Approve/Reject/Archive available.

![10-approved-answers](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/10-approved-answers.jpg)

## Screenshot 11-answer-form · Step 6

New answer empty submission focuses required title via native validation; placeholder-only visible fields, aria labels present. Right detail remains for old item.

![11-answer-form](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/11-answer-form.jpg)

## Screenshot 12-knowledge-review · Step 7

Resolve defaults to sending answer to lead AND proposing reusable approved answer. Button does not disclose these effects; draft note placeholder also allows internal resolution. No message sent.

![12-knowledge-review](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/12-knowledge-review.jpg)

## Screenshot 13-test-center · Step 8

Fresh default Test Center, no test runs or live providers connected.

![13-test-center](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/13-test-center.jpg)

## Screenshot 14-release-check · Step 8

Launch is clearly locked, but machine identifiers in blocking checks and 0% safety failures with no runs can mislead.

![14-release-check](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/14-release-check.jpg)

## Screenshot 15-settings-qualification · Step 9

Budget range visibly shows 20000000 under TZS 200,000–500,000. Source directly binds min_cents; raw money units leak into form. No controls to add/edit offers on this page.

![15-settings-qualification](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/15-settings-qualification.jpg)

## Screenshot 16-settings-booking · Step 9

Readable short form, but timezone is free text; no calendar connection, weekday selector, exceptions or preview on this page.

![16-settings-booking](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/16-settings-booking.jpg)

## Screenshot 17-settings-team · Step 10

Intermediate page points to Open teams and exposes existing Chatwoot account configuration wording. Target team editor not inspected.

![17-settings-team](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/17-settings-team.jpg)

## Screenshot 18-settings-followups · Step 9

Delay displayed as 1440 minutes, with no natural-language schedule or message preview. Enabled is configuration only; live dispatch not exercised.

![18-settings-followups](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/18-settings-followups.jpg)

## Screenshot 19-settings-alerts · Step 10

Alerts leads to generic Open inboxes without alert recipients, triggers or delivery-status guidance on this page.

![19-settings-alerts](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/19-settings-alerts.jpg)

## Screenshot 20-settings-whatsapp · Step 10

WhatsApp entry is a generic Open inboxes handoff with Chatwoot wording, no connection status summary.

![20-settings-whatsapp](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/20-settings-whatsapp.jpg)

## Screenshot 21-inbox-settings · Step 10

Settings subnavigation disappears; generic multichannel explanation and unlabeled edit/delete icon controls.

![21-inbox-settings](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/21-inbox-settings.jpg)

## Screenshot 22-add-inbox · Step 10

WhatsApp V1 setup exposes Website, SMS, Email, API, Telegram and Line alongside WhatsApp; no setup submitted.

![22-add-inbox](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/22-add-inbox.jpg)

## Screenshot 23-ai-provider · Step 11

AI provider configuration in disconnected local test environment.

![23-ai-provider](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/23-ai-provider.jpg)

## Screenshot 24-phone-inbox · Step 12

Phone 390×844, Inbox opens selected conversation. Lead name readable but repeated phone; AI/Human owner status hidden until expanding details; next action truncates. Composer occupies ~230px.

![24-phone-inbox](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/24-phone-inbox.jpg)

## Screenshot 25-phone-brief · Step 12

Expanded phone brief: still no explicit Human Active or assignee; disabled Resume AI has no visible explanation.

![25-phone-brief](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/25-phone-brief.jpg)

## Screenshot 26-phone-queue · Step 12

Confirmed visible dead end after Back to list: Select a conversation but no list or selection control at 390px. This is loaded application state, not a blank capture.

![26-phone-queue](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/26-phone-queue.jpg)

## Screenshot 27-phone-leads · Step 12

At 390×844, expanded filters and stacked headers leave only part of first lead visible before fixed pagination. Import/export lose accessible names in DOM.

![27-phone-leads](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/27-phone-leads.jpg)

## Screenshot 28-phone-bookings · Step 12

Phone booking cards reflow and keep names readable, but tall toolbar/filters reduce available space; virtual keyboard and actual touch not tested.

![28-phone-bookings](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/28-phone-bookings.jpg)

## Screenshot 29-phone-settings · Step 12

Phone Settings loses all section navigation; Save changes wraps and clips in fixed height. Viewport and document width both390, so this is not page-wide overflow.

![29-phone-settings](/Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/ui-ux-audit/2026-09-09/screenshots/29-phone-settings.jpg)
