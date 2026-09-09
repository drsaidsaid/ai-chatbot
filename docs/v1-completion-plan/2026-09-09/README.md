# Standalone V1 completion plan

9 September 2026 · Approved and published for implementation

The UI/UX audit recommendations are approved. This plan makes the next work concrete: simplify navigation, fix the broken operator paths, finish the standalone features, then prove the exact release is safe to operate.

**Approved main menu: Inbox · Leads · Bookings · Knowledge · Settings.**

[Approved navigation](./navigation.md) · [UI/UX audit](../../ui-ux-audit/2026-09-09/README.md) · [Functional audit](../../integration-audit/2026-09-09/detailed-audit.md)

## Status

- The owner approved all 18 tickets and requested one separate Codex task per ticket until completion.
- All 18 tickets are published as GitHub issues #18–#35 with blocker links; individual task creation and execution are tracked in execution-state.json.
- Google Calendar was explicitly selected as the first V1 calendar provider.
- Work is combined by the coordinator on codex/v1-completion-20260909 in /Users/ghalyasaid/Documents/projects/AI-Lead-V1-Integration.
- The older broad feature issues remain unchanged. Their status and local historical Done notes are not current release evidence.
- The published bodies are authoritative; the drafts folder is retained as the reviewed proposal history.

## First actions

1. Published: issues #18–#35. Create and run one task per ticket, respecting the blockers.
2. Establish one reproducible release and update its requirements/design records with the approved navigation.
3. Deliver the first complete desktop/phone Inbox path so the new look and daily workflow can be judged in the in-app browser.
4. Finish the remaining paths and run current release checks, recovery checks and an explicitly authorized supervised pilot.

R01 and R02 are the first implementation sequence. Messaging safety and role-scope work remain prerequisites for live use; a prettier screen does not unblock delivery.

## Approved breakdown

1. **[R01 — Reproduce and document one canonical V1 release](./published/01-reproduce-and-document-one-canonical-v1-release.md)**
   - **Blocked by:** None.
   - **User story covered:** An owner can identify exactly which version is being tested and released.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/11

2. **[R02 — Sign in and navigate the simplified app on desktop and phone](./published/02-sign-in-and-navigate-the-simplified-app-on-desktop-and-phone.md)**
   - **Blocked by:** R01.
   - **User story covered:** A Human Operator can enter the app, reach each permitted work area and return to a conversation list.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/13

3. **[R03 — Connect WhatsApp and receive one verified durable conversation](./published/03-connect-whatsapp-and-receive-one-verified-durable-conversation.md)**
   - **Blocked by:** R01, R02.
   - **User story covered:** An administrator can connect the Business Account's WhatsApp number and know whether an incoming message was accepted.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/16

4. **[R04 — Deliver an eligible reply once and recover safely](./published/04-deliver-an-eligible-reply-once-and-recover-safely.md)**
   - **Blocked by:** R03.
   - **User story covered:** A Lead receives one eligible reply, and the Human Operator sees an honest delivery outcome.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/16

5. **[R05 — Honor a natural-language stop request in the live conversation](./published/05-honor-a-natural-language-stop-request-in-the-live-conversation.md)**
   - **Blocked by:** R03, R04.
   - **User story covered:** A Lead can ask to stop and the app immediately stops automated contact.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/10

6. **[R06 — Invite a team member with access only to assigned Leads](./published/06-invite-a-team-member-with-access-only-to-assigned-leads.md)**
   - **Blocked by:** R01, R02.
   - **User story covered:** An administrator can invite a team member without exposing other Leads or business settings.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/13

7. **[R07 — Understand and control a Conversation without misleading actions](./published/07-understand-and-control-a-conversation-without-misleading-actions.md)**
   - **Blocked by:** R02, R04, R05, R06.
   - **User story covered:** A Human Operator can read the conversation, take over, reply privately or publicly, and explicitly hand control back.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/13

8. **[R08 — Find, inspect and maintain a Lead without losing context](./published/08-find-inspect-and-maintain-a-lead-without-losing-context.md)**
   - **Blocked by:** R02, R06.
   - **User story covered:** A Human Operator can find an assigned Lead, understand the next action and open the correct Conversation.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/13

9. **[R09 — Configure an Offer and qualify a Lead from supported evidence](./published/09-configure-an-offer-and-qualify-a-lead-from-supported-evidence.md)**
   - **Blocked by:** R02, R03, R05, R06.
   - **User story covered:** An administrator can set an Offer's questions and thresholds, and a Lead receives the correct next question and Qualification.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/8

10. **[R10 — Connect and control the AI provider with visible health and limits](./published/10-connect-and-control-the-ai-provider-with-visible-health-and-limits.md)**
   - **Blocked by:** R01, R02, R06.
   - **User story covered:** An administrator can configure the AI Employee and stop or limit its use with confidence.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/7

11. **[R11 — Publish knowledge that answers only the relevant question and Offer](./published/11-publish-knowledge-that-answers-only-the-relevant-question-and-offer.md)**
   - **Blocked by:** R09, R10.
   - **User story covered:** An administrator can approve business knowledge and a Lead receives a supported, context-aware answer.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/15

12. **[R12 — Resolve a Review Request and optionally propose knowledge](./published/12-resolve-a-review-request-and-optionally-propose-knowledge.md)**
   - **Blocked by:** R07, R11.
   - **User story covered:** A Human Operator can answer one Lead or record a private resolution, then separately propose a reusable answer.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/17

13. **[R13 — Book and manage one genuinely available call](./published/13-book-and-manage-one-genuinely-available-call.md)**
   - **Blocked by:** R04, R07, R09, R11.
   - **User story covered:** A Highly Qualified Lead can agree on a real available time and the assigned Human Operator can manage the Booking.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/12

14. **[R14 — Assign human work and deliver one useful Alert](./published/14-assign-human-work-and-deliver-one-useful-alert.md)**
   - **Blocked by:** R03, R04, R06, R09, R12.
   - **User story covered:** The right Human Operator receives a useful Alert and opens the specific work needing attention.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/9

15. **[R15 — Schedule one permitted follow-up and stop it when circumstances change](./published/15-schedule-one-permitted-follow-up-and-stop-it-when-circumstances-change.md)**
   - **Blocked by:** R04, R05, R07, R09, R11.
   - **User story covered:** A Lead who stops answering can receive the permitted reminder, and later contact stops when it should.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/10

16. **[R16 — See trustworthy basic business results without another main menu](./published/16-see-trustworthy-basic-business-results-without-another-main-menu.md)**
   - **Blocked by:** R06, R08, R09, R13, R14.
   - **User story covered:** An administrator can see whether Leads are being answered, qualified and booked without opening a generic reporting suite.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/13

17. **[R17 — Approve launch only from current test and pilot evidence](./published/17-approve-launch-only-from-current-test-and-pilot-evidence.md)**
   - **Blocked by:** R02, R03, R04, R05, R06, R07, R08, R09, R10, R11, R12, R13, R14, R15, R16.
   - **User story covered:** An administrator can tell whether the exact current app and configuration passed the required checks.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/14

18. **[R18 — Deploy a recoverable release and complete a supervised V1 pilot](./published/18-deploy-a-recoverable-release-and-complete-a-supervised-v1-pilot.md)**
   - **Blocked by:** R17.
   - **User story covered:** The owner can operate the deployed app, stop automation and recover data before wider use.
   - **Existing parent:** https://github.com/drsaidsaid/ai-chatbot/issues/7

## Publication and completion rules

Publish these as focused follow-ups linked to the verified existing parent issues; do not modify or close the parents as part of publication. Keep synchronized local ticket records in docs/issues per the repository delivery guide. Resolve final local IDs against the canonical release, since this task's older checkout and the audited release have different local numbering.

Use the configured ready-for-agent label only after the individual slice is specified and its required decisions are recorded. Blocked work keeps explicit dependency references; unfinished provider choices receive needs-info rather than a false ready label. Replace R identifiers with real published issue references in all blocker lists.

Implementation follows the existing ADRs, domain glossary and delivery flow. Update the PRD, technical design and applicable ADRs before building on a changed decision. Do not overwrite dirty donor work. Prove the behavior across every relevant layer and capture the real in-app browser path. New UI tests should test actual behavior, not repeat the implementation.

## Coverage and deliberate exclusions

The breakdown covers the audit's navigation/mobile failures, visual inconsistency, incorrect actions, notes/replies, permissions, live messaging reliability, opt-out, offer qualification, knowledge grounding, calendar booking, alerts, follow-ups, provider controls, required basic analytics and release operations.

Online Profits identity, offer-journey sync, payments, access, memberships, coaching roles and LTV stay in the separate integration plan. Standalone V1 retains the documented fixed roles and one WhatsApp connection; no billing, CRM sync, broad marketing campaigns, other messaging channels, enterprise features or parallel frontend is added.

The audit's unverified production environment is a verification task, not a claim that every operational control is missing. Synthetic fixture anomalies excluded from the UI audit remain excluded here.

## Approval record

The owner instructed: “Proceed with all tickets with each in their own threads until completion.” The owner then selected “Google Calendar (recommended)” for V1 bookings. Ticket publication and separate task execution are authorized. Live external actions still follow the concrete acceptance requirements in R18.
