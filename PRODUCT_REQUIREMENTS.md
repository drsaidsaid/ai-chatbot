> Current product authority: [12 September approved agreement](docs/v1-alignment-2026-09-12/PRODUCT_AGREEMENT.md) and ADR 0016 supersede earlier fixed sales assumptions. Working brand pending availability.

# AI Lead Employee

## Product Requirements Document

**Status:** Approved standalone V1 completion baseline
**Revision:** 5 (2026-09-09)
**Working product name:** AI Lead Employee  
**Initial channel:** WhatsApp  
**Initial customer:** Our own online education and AI employee services business  
**Delivery model:** Done-for-you service

## 1. Product Summary

AI Lead Employee is a WhatsApp-based AI employee that receives incoming lead messages, answers approved business and offer questions, qualifies each lead, books calls with highly qualified leads, and alerts the right human with a concise explanation of why the lead deserves immediate attention.

The product exists so the business owner and sales team spend their time speaking to qualified buyers instead of manually answering every inquiry.

The first version will be built and tested internally. Once it performs reliably, it can become a done-for-you service for businesses with high WhatsApp inquiry volume and valuable customers, initially considering clinics, real estate businesses, and other high-ticket service providers.

## 2. Product Goal

R03 connection acceptance follows ADR 0009: administrators configure one direct
Meta connection in Settings, with encrypted credentials and saved actionable
health. All supported callbacks require signatures. Authenticated receipts,
complete batch normalization and recoverable processing precede any claim of
successful receiving; late delivery updates, including already queued legacy
work, cannot regress delivered/read or expose raw provider errors. Setup and
readiness bind the saved phone number to Meta's identity; a phone-only edit
requires renewed callback registration.
Local proof uses an isolated fake provider; real Meta delivery is a separate
authorized-assets check.

The v1 goal is to prove that an AI employee can reliably handle incoming WhatsApp inquiries and hand off only the right leads without losing strong prospects or creating harmful answers.

The product succeeds when it:

- Responds quickly and naturally to incoming WhatsApp leads.
- Answers common questions using approved business knowledge.
- Collects enough information to classify lead quality accurately.
- Books available call times for highly qualified leads.
- Immediately alerts the assigned human with full context.
- Reduces the number of low-value conversations handled by humans.
- Gives administrators a clear operational view of every conversation and decision.

## 3. V1 Scope

### Included

- Direct Meta WhatsApp Business Cloud API integration through the owned
  Community Edition WhatsApp channel path.
- An owned inbox frontend and backend derived from the Community Edition source.
- First-party AI-to-human handoff, qualification panel, and operational queues.
- First-party user authentication, role management, and tenant-scoped database.
- AI replies to inbound text messages.
- Approved FAQ, offer, pricing, objection, and policy knowledge.
- Configurable qualification questions and rules.
- Lead extraction, scoring, and classification.
- Offer-configured booking eligibility, with separate fit/readiness and optional verified payment requirements.
- Google Calendar availability plus custom booking hours (R13).
- WhatsApp alerts to configurable human recipients.
- Shared dashboard inbox and lead list.
- Per-conversation AI pause, human takeover, and manual resume.
- Team assignment and basic roles.
- Human review of unanswered or sensitive questions.
- Approval-based knowledge improvement.
- Follow-up messages for incomplete conversations.
- Basic analytics, testing tools, audit history, CSV export, and manual lead import.
- Saved operational queues using owned labels, priorities, snoozing, and filters.
- Human replies and private notes; generic macros/canned-response administration stays hidden in V1.
- Click-to-WhatsApp advertisement attribution when Meta referral data is available.
- Business-hours-aware human handoff messaging.
- Optional WhatsApp Business app coexistence when supported by Meta and the connected account.

### Correction Baseline

The V1 implementation baseline is the owned Community Edition Rails and Vue
application. There is no Chatwoot Cloud account, Chatwoot API token, Chatwoot
webhook secret, separate Chatwoot database, or external Chatwoot runtime.

The canonical WhatsApp path is:

1. Meta sends a verified WhatsApp event to the existing owned Community Edition
   WhatsApp webhook.
2. The existing WhatsApp event job and channel service create or update the
   tenant-scoped Lead identity, Conversation, and visible Inbound Message.
3. Before any automated response is recorded, explicit stop language is
   recognized from the persisted Inbound Message and durably suppresses every
   Conversation for that Lead in the Business Account.
4. If a Channel Greeting is configured, this is the first Lead message, and the
   Lead has not opted out, the
   greeting is recorded and sent as visible conversation history.
5. After message persistence commits, durable AI Orchestration evaluates the
   actual Lead message with current Control State and approved Knowledge Items.
6. The AI Employee creates a persisted Outbound Message intent with verified
   Source References or creates safe Review Request behavior.
7. The existing WhatsApp outbound sender delivers the reply through Meta and
   delivery status webhooks reconcile the Message.

The current release authority and reproducible schema decision are recorded in
[ADR 0008](docs/adr/0008-canonical-v1-release-and-schema-provenance.md).
The chosen runtime starts at audited commit `74d156e327e3ddb2deedd1503c6d1c04b0b1359e`
plus the documentation-only integration bootstrap `5c3bbc2f900948fcdd6729159701b9cc993b85b5`.
The canonical CE webhook, durable orchestration and encrypted provider connection
are present. Historical 000–019 Done notes do not certify the new R01–R18
acceptance paths. The [active tickets](docs/issues/v1-completion-20260909/README.md)
control current implementation and proof.

### Approved navigation and standalone boundary

There are five primary destinations: **Inbox, Leads, Bookings, Knowledge,
Settings**. Phones expose Inbox, Leads, Bookings and More, with Knowledge and
Settings inside More. Hot Leads and customer Review Requests are Inbox views.
Knowledge owns reusable content Drafts & approvals. Full Test Center is under
Settings → AI & testing; contextual test shortcuts open that same system.
See the [approved navigation specification](docs/v1-completion-plan/2026-09-09/navigation.md).

Basic analytics are required in Leads and relevant workspaces; the generic CE
Reports suite is hidden. One direct Meta WhatsApp connection serves each
Business Account, including Human Operator replies and authorized Alerts.
Google Calendar is the first provider. Fixed Admin and Team Member roles remain;
Online Profits identity, purchases, access and membership integration are separate.

### Not Included

- Facebook Messenger or Instagram Direct integration.
- YouTube or TikTok message handling.
- Fully unattended onboarding; V1 guided setup is initially assisted.
- Automatic understanding or transcription of voice notes.
- Deep interpretation of images, documents, or other media.
- Cross-channel identity matching.
- Google Sheets synchronization.
- Fully autonomous custom pricing, refunds, legal advice, or medical advice.
- Guaranteed sales or revenue claims.
- Chatwoot Enterprise features or code requiring a commercial license.
- Online Profits membership/CRM integration, automated online subscription collection and broad autonomous marketing. Manual platform billing, inbound ad-set routing and bounded template broadcasts are included by ADR 0016.
- Additional messaging channels or multiple WhatsApp connections per Business Account.

## 4. Users and Roles

### Admin

The business owner or administrator can:

- View all leads and conversations.
- Configure the agent, qualification rules, questions, offers, knowledge, booking rules, alerts, assignments, and follow-ups.
- Edit any extracted lead information.
- Take over, reply, assign, reassign, pause, or resume conversations.
- Approve or reject new knowledge.
- Review analytics, audit history, and test results.
- Import and export leads.

### Team Member

R06 enforces these permissions through current Conversation assignment, including
search, counts, downloads, realtime and queued work. Shared Lead identity never
grants another Conversation's content; mixed-access Qualification summaries are
withheld while permitted evidence remains available. Unsupported macro endpoints
are blocked in V1. Lead merging and bulk deletion require current Admin access;
bulk labels affect only currently accessible Leads. See ADR 0010.

A team member can:

- View and respond to assigned leads only.
- Receive alerts for assigned leads.
- Edit details and add private notes on assigned leads.
- Take over an assigned conversation.
- Request that a human answer be considered for the knowledge base.

All human messages are sent through the same WhatsApp business number. The first human message may optionally introduce the team member by name.

## 5. Lead Data Model

Every tenant-owned record must resolve a hidden Business Account scope from the beginning, even though v1 serves one internal business. In the CE runtime this is normally `account_id` on `Account`, `AccountUser`, `Contact` and related records, not a duplicate tenancy system. This prepares the system for future multi-client use without exposing multi-client controls in the initial interface.

The lead record should support:

- Name.
- WhatsApp phone number.
- Business name.
- Business type.
- Location.
- Email, if voluntarily provided.
- Current problem or desired outcome.
- Estimated inquiries per day or month.
- Urgency.
- Budget range and budget evidence.
- Decision-maker status.
- Preferred or confirmed call time.
- Lead source and campaign information.
- Lead quality.
- Follow-up state.
- Assigned human.
- Private notes.
- Conversation summary.
- Qualification reasons and missing information.
- Created, updated, and last-contacted timestamps.

WhatsApp phone number is the primary duplicate key in v1. Returning leads should be recognized, their history used, and their qualification updated when circumstances change.

## 6. Lead Status Model

Lead quality and operational follow-up must be separate fields. A lead can be qualified while still requiring follow-up, or unqualified while a conversation remains active.

### Lead Quality

Keep stable outcome labels: Unknown, Unqualified, Low Qualified, Qualified and Highly Qualified. Their business evidence comes from the selected Offer's published rules, never a universal business/revenue/budget checklist. Unknown is not rejection. When qualification is deliberately disabled, show Not required as configuration context without fabricating an outcome.

Keep business fit, readiness to speak/buy, action eligibility, Follow-up State and Control State distinct. Reports retain the rules and evidence behind a decision.

## 7. Qualification Framework

Qualification is explicitly not configured, disabled or enabled per Offer. With absent rules the agent may answer approved information, but cannot invent questions or qualification. An owner chooses the appropriate next step; purchase links and enquiries need not require calls.

Owners write requirements naturally or import documents. A readable preview identifies fields, types, required evidence, rules, unknowns and next steps; only publication activates them. Ask at most one useful question when appropriate, skip known information and accept corrections. No default lead-volume interview, business-existence rejection or universal budget bands. Strictness means explicit approved evidence and readiness requirements. Human feedback can propose changes, never silently publish them.

## 8. Conversation Behavior

### Tone

The agent acts as a warm business advisor: friendly, brief, respectful, professional, and focused on diagnosis. It should sound natural without pretending to be a specific human.

### Conversation Rules

- Answer relevant questions briefly using approved knowledge.
- Ask at most one relevant qualification question when needed and enabled; answering does not force another question.
- Do not repeat questions already answered in the current conversation or remembered lead history.
- Extract answers even when the lead provides several details in one message.
- Continue from the point where an interrupted conversation stopped.
- Do not interrogate the lead or expose internal scoring rules.
- Do not promise a call unless the selected Offer action is permitted, the Lead agrees, and an actual handoff or Booking supports that promise.
- Redirect immediately when a lead asks about topics outside the business or service.
- Never invent an answer when approved knowledge is insufficient or conflicting.
- Do not greet twice. A configured Channel Greeting may welcome the Lead, but
  the AI Employee's answer should respond to the actual Lead message and omit a
  second salutation.

### Buying Questions and Human Help

There is no fixed two-answer limit. Answer approved buying questions; politely redirect personalised strategy toward configured resources, qualification or an applicable paid Offer. Relevant unknown questions receive truthful acknowledgment and an actual Review Request. Unrelated requests receive a boundary, not a needless team alert.

Basic human assistance is available separately from a qualified sales appointment. Do not trap a person refusing further automated questions. Route help and sales work separately; human takeover pauses AI until explicit resume.

### Out-of-Scope and Sensitive Topics

The agent must escalate instead of improvising on:

- Legal or medical advice.
- Guarantees or promises of results.
- Exact custom pricing.
- Refund decisions.
- Private company information.
- Relevant business questions lacking approved information. Unrelated questions are politely redirected.

### Voice Notes and Media

- Voice notes are stored and visible to humans.
- The AI replies: "I could not listen to your audio. Please send your message as text."
- Other media is stored and flagged for human review.
- V1 does not deeply interpret voice notes or attachments.

### Opt-Out

The system must recognize clear English, Swahili, and mixed-language requests to
stop automated contact, including polite forms such as "please stop messaging
me" and "tafadhali usinitumie ujumbe tena." It must distinguish those requests
from unrelated refusals, negated stop phrases, quoted examples, and questions
about stopping. Recognition is deterministic and does not call the AI Provider.

The verified Inbound Message and immutable Consent Evidence must commit before
the canonical WhatsApp event is complete. The same transaction records the
active Business Account/Lead suppression and invalidates unsent AI replies,
Channel Greetings, and automatic follow-ups across the Lead's Conversations.
Duplicate provider events have no second effect. A distinct later withdrawal is
retained as additional evidence. Opt-out does not close or rewrite Qualification.

An active withdrawal blocks automated Lead-facing messages at the final R04
dispatch check, including work restored by queue recovery or process restart.
If dispatch authorization committed before the withdrawal, the recorded
accepted or unknown provider outcome remains truthful; later contact is still
suppressed. The incoming stop Message remains visible for Human Operator review,
and no automated acknowledgment is sent, including for a stop combined with a
complaint, refund, support, or human request.

Re-consent requires an administrator to select a newer verified Inbound Message
that explicitly permits automated contact again. The action records immutable
Consent Evidence, sends nothing, and never resumes the AI. It rejects ambiguous,
foreign, stale, or previously used evidence and a concurrent newer withdrawal.
AI resume, a generic "yes" or "hello," import, or Lead edit cannot clear opt-out.
Clearing the current suppression does not revive canceled, failed, unknown, or
pre-withdrawal work; only a fresh later eligible event may create new work.

## 9. Knowledge and Answering

V1 knowledge is manually added and approved in the dashboard.

Knowledge priority is:

1. Approved FAQ.
2. Approved offer document.
3. Approved pricing, objection, and policy entries.
4. Supporting business documents.

Higher-priority sources override lower-priority sources when they conflict. If two authoritative entries conflict, the agent must request human review instead of choosing one.

When the agent cannot answer:

1. It tells the lead that it is checking the question.
2. It creates a human-review item in the dashboard.
3. It sends a WhatsApp alert when the question is urgent, blocks a qualified lead, or comes from an angry lead. Other questions may be batched.
4. A human answers from the dashboard.
5. The answer is sent to the lead in the same WhatsApp conversation.
6. The system asks whether the human wants to save the answer for future use.
7. If approved, the human chooses FAQ, offer details, pricing, objection handling, or policy before publishing it.

The system must never learn automatically from every human answer.

The AI provider integration must be OpenAI-compatible and provider-neutral.
OpenRouter is the initial provider, but the product must store encrypted
server-side credentials, expose provider configuration only to authorised Platform Operators, classify
provider failures, and avoid fabricated fallback answers.

Under ADR 0016, only the Platform Operator configures encrypted provider credentials and models. Business Account admins see their managed service and account-isolated usage, not provider key/model controls. R21 migrates the existing R10 account-owned baseline with explicit authorisation and rollback.

R10 must distinguish saved configuration from readiness to answer at the actual
configured reply budget. A tiny successful probe cannot mask insufficient
credits for a normal answer. Show the checked model/budget/time, safe failure
reason and retry guidance; configuration changes invalidate stale readiness.
Actual usage is collected where supplied; unavailable cost remains unknown.
An explicit daily request allowance with bounded requests is V1's conservative
usage guardrail, not a guaranteed monetary spending cap. Disablement or allowance
exhaustion blocks new model work and pending automated delivery through the
shared sender boundary; already authorized dispatch cannot be retracted.
Provider/configuration changes invalidate relevant launch evidence.

R11 owns a truthful non-model acknowledgment and Review Request on provider
failure when automation is still permitted. It must preserve R04's delivery and
control authority; a failure acknowledgment cannot bypass an explicit disable or
exhausted local allowance. The [R10 preparation](docs/v1-completion-plan/2026-09-09/r10-provider-controls-preparation.md)
specifies public acceptance boundaries. These are pending completion requirements,
implemented on the focused R10 branch from `324ee6df` and verified there before
the coordinator integrates them.

## 10. Booking

Offer-configured fit/readiness and Lead agreement determine sales-call eligibility. Basic human assistance is separate. Optional paid appointments additionally require verified Offer payment before booking.

Booking availability is the intersection of:

- Free time on the connected calendar.
- Admin-configured days and booking hours.
- Blocked times, buffers, and minimum notice.

The agent offers available times or selects the next acceptable free time with the lead's agreement. It must prevent double booking.

After booking:

- Send a WhatsApp confirmation to the lead.
- Add the event to the connected business calendar.
- Send a calendar invitation only when the lead voluntarily provides an email address.
- Mark the lead's follow-up state as Call booked.
- Alert the assigned human immediately.

The admin can configure weekdays, weekends, and time windows. Do not assume Online Profits business hours for other accounts; owners review availability before activating booking.

## 11. Human Alerts

Alert recipients are configurable by alert type. Urgent alerts default to the admin until assignment rules are proven.

### Alert Types

- Hot lead.
- Booked call.
- Urgent human review.
- Knowledge approval request.

### Hot Lead Alert Content

- Full name and WhatsApp number.
- Business name, type, and location when captured.
- Problem and desired outcome.
- Lead or inquiry volume.
- Urgency.
- Budget signal.
- Decision-maker status.
- Why the lead is highly qualified.
- Missing or uncertain information.
- Recommended next action.
- Suggested or confirmed call time.
- Link to the full conversation in the dashboard.

### Booked Call Preparation

The booked-call alert should also include:

- A concise conversation summary.
- The strongest qualification evidence.
- A likely objection.
- A suggested first question for the human to ask.

## 12. Assignment and Human Takeover

R04 requires one durable dispatch owner per outgoing WhatsApp Message, including
Channel Greetings. Before dispatch, current sender access and automation authority
are rechecked. Pending automation is canceled on takeover, assignment, private
or public human reply, pause, closure, recorded opt-out or launch withdrawal.
Slow AI work must not delay human control. Inbox delivery outcomes distinguish
pending, canceled, failed and unknown from provider acceptance and delivery.
Unknown acceptance requires reconciliation or a Review Request without automatic
resending; lost queue operations and interrupted claims recover durably (ADR 0011).
Acceptance displays as awaiting delivery until a provider receipt establishes
sent/delivered/read history. A local preparation failure remains eligible for an
authorized retry. Review rejection and alert dispatch authorization must serialize.
Delayed creation notifications carry the saved delivery outcome and reconcile
the operator's optimistic reply with its saved Message into one Inbox row.
Booking cancel/reschedule notices use the same durable sender, attributed to the
initiating operator, with one persisted notice per mutation identity.

- Leads have a default owner.
- An admin may manually assign or reassign any lead.
- V1 supports automatic assignment structure, initially default-owner based, with future rules for round-robin, offer, and availability.
- The assigned human receives the direct WhatsApp alert; the admin may be copied on high-priority alerts.
- Reassignment remains possible after booking and must be recorded in the audit history.
- When a human sends a reply, the AI pauses automatically for that conversation.
- A WhatsApp Business app coexistence echo is treated as human activity for
  Control State.
- A human assignment, handoff, pause, reply, or resolution cancels any pending AI reply before it can be sent.
- Before every outbound AI message, the system must recheck that the AI still owns the conversation; an already-queued reply must be blocked after human takeover.
- The AI resumes only when a human explicitly resumes it.
- Resuming the AI does not immediately send a message; it permits the next eligible lead message or scheduled action to be evaluated.
- Internal notes are never sent to the lead.

## 13. Follow-Up

For unfinished permitted conversations, default to at most one contextual reminder and one friendly closing invitation, with configurable timing. Recheck current consent, control, action, Offer and channel permission at send. Stop sales chasing on refusal, opt-out, payment, booking, closure or human ownership. Necessary transactional updates are separately authorised. Hesitation is not refusal. The customer may return later.

Ordinary free-form permission is measured from the latest customer message, not a universal 72-hour allowance. Use an eligible approved template outside the permitted window or suppress the action. No automatic retry of uncertain sends.

## 14. Dashboard Requirements

### Inbox

All conversations includes new inquiries without Qualification and multiple Conversations for one Lead. Needs review and Hot leads are views, with booked and due follow-up filters. List/detail, browser back and refresh preserve the selected queue and filters at phone and desktop widths.

- The owned inbox displays all permitted conversations in a familiar messaging layout.
- Filters for quality, follow-up state, assignee, source, unanswered questions, and booking status.
- Search by name, phone number, business, or message text.
- Visible AI/human control state.
- Reply, pause, resume, assign, and add-note actions.
- Saved queues for hot leads, human review, follow-up due, and booked calls.
- Human replies and private notes; generic macros and canned-response administration remain gated.

### Leads

- Table of contact details, quality, score, source, assignee, last activity, and next action.
- Editable extracted fields.
- Clear qualification explanation and missing signals.
- CSV export and manual lead import.

### Inbox → Hot leads

- Prioritized list of highly qualified leads and booked calls.
- Qualification reasons and contact details visible without opening each conversation.

### Inbox → Needs review

- Unanswered questions.
- Sensitive or conflicting requests.
- Angry or urgent conversations.
- Correct-answer entry and send action.

### Knowledge

- FAQ, offer details, pricing, objections, policies, and supporting documents.
- Draft, approved, and rejected states.
- Source priority and conflict visibility.
- Approval workflow for human answers.

### Settings

- Offers and target customer profiles.
- Qualification questions, hard rules, scoring, and budget ranges.
- Booking hours and connected calendar.
- Alert recipients and alert types.
- Team members and assignments.
- Follow-up timing and message rules.
- Sandbox/test mode.

### Basic analytics within Leads and relevant workspaces

R16 must define time range, timezone, denominators, role scope and empty states.
These metrics do not add a sixth main-menu item or enable generic CE Reports.

- Total conversations.
- Lead quality breakdown.
- Highly qualified leads.
- Calls booked.
- Unanswered questions.
- Qualification-to-booking conversion.
- Source and campaign quality.
- Average first response time.
- Human takeover frequency.

## 15. Lead Sources

V1 supports these source labels:

- WhatsApp direct.
- Facebook ad.
- Instagram ad.
- Organic.
- Referral.
- Unknown.

Campaign information should be stored whenever it is available. Ad-set and individual-ad mappings select approved Offer context under ADR 0016; missing source information uses explicit fallback rather than guessing.

## 16. Audit and Data Requirements

The audit history must record:

- Every AI and human message.
- Lead field edits.
- Quality, score, and follow-up changes.
- Qualification reasons.
- Booking creation and changes.
- Assignment and reassignment.
- AI pause and resume actions.
- Knowledge additions, approvals, edits, and rejections.
- Alerts sent and delivery outcomes.

Conversation history is retained by default in v1. Configurable deletion and export policies are deferred, but the architecture should not prevent them.

## 17. Business Model

The platform sells a managed monthly AI service with an included logical-reply allowance and optional prepaid extras; clients do not buy LLM keys. Collect payments manually first. Only authorised payment confirmation activates a subscription, top-up or upgrade. Display usage percentage, remaining units and renewal date.

Included units reset on renewal; extras carry forward while subscribed, consumed after included units. Upgrade by charging the current cycle plan-price difference, increasing total allowance while preserving consumption, extras and renewal date. No surprise charges. At exhaustion pause AI but retain the human inbox and incoming messages. Provider costs remain distinct from customer charges.

Meta WhatsApp messaging and ad spend are separately billed by Meta and clearly disclosed. Static template fan-out does not charge an AI reply per recipient. Platform-only reports show revenue, costs, unknown-cost records and estimated contribution margin. Benchmark models before approving price/allowance combinations; earlier setup/monthly price hypotheses are not approved sellable tariffs.

## 18. Testing and Launch

### Sandbox

Admins must be able to simulate a WhatsApp conversation without contacting real leads. Test conversations should display the selected answer, extracted data, quality, score, next question, escalation decision, and booking decision.

### Evaluation Labels

Each test conversation can be graded for:

- Qualification accuracy.
- Answer correctness.
- Tone.
- Whether the right next question was asked.
- Whether escalation was appropriate.

Incorrect messages can be marked wrong, corrected, and optionally proposed for the approved knowledge base.

### Launch Sequence

1. Manually written test scenarios.
2. Team roleplay conversations.
3. At least 50-100 simulated or low-risk conversations.
4. Controlled low-budget ad traffic to the new AI WhatsApp number.
5. Gradual traffic increase after quality remains stable.

### Launch Gate

The admin may approve live operation only when:

- Qualification decisions are correct in at least 85-90% of reviewed tests.
- There are zero serious harmful, fabricated, or policy-breaking answers.
- Highly qualified leads are not booked without the required evidence.
- Calendar booking prevents conflicts.
- Human takeover, pause, resume, alerts, opt-out, and unanswered-question flows work end to end.

## 19. Primary Acceptance Scenarios

The v1 is complete only when all of these scenarios work:

1. A new WhatsApp lead asks a question, receives an approved answer, completes qualification one question at a time, is marked highly qualified, books an available call, and triggers a complete human alert.
2. An unqualified lead asks for a human, is politely kept in the AI conversation, and does not create an unnecessary handoff.
3. A qualified but non-urgent lead is recorded accurately without receiving an automatic booking.
4. A returning lead is recognized and reclassified when new budget or urgency evidence appears.
5. An unknown question is escalated, answered by a human, sent to the lead, and optionally added to the correct knowledge category after approval.
6. A human takes over a conversation, the AI pauses, and it does not resume until explicitly enabled.
7. An AI reply queued before human takeover completes late and is blocked without sending.
8. Meta delivers the same inbound event twice, but the lead receives only one AI reply and no duplicate side effect.
9. A resolved conversation receives a new lead message, retains the remembered Lead identity, and starts a new AI-controlled lifecycle.
10. A voice note is stored and the lead is asked to send text.
11. A lead opts out and receives no further automated follow-up.
12. Two leads cannot book the same calendar time.
13. A team member sees only assigned leads while the admin sees all leads and activity.

## 20. Deferred Decisions

These decisions do not block v1 planning but must be resolved before related implementation:

- Final public product name.
- First external niche after the internal pilot.
- Each Business Account’s published fit/readiness requirements; no universal scoring defaults.
- Exact included AI reply allowances, plan prices and prepaid top-up prices.
- WhatsApp Business account and number used for the pilot.
- Google Calendar is confirmed for the first integration.
- Final data retention and deletion policy.
- Languages supported at launch beyond the initial business requirements.

## 21. Architecture and Data Ownership

AI Lead Employee is the system of record for its inbox, message delivery,
contacts, conversations, human replies, private notes, assignments, labels,
qualification, evidence, AI/human control state, knowledge, booking, alerts,
follow-up, audit, evaluations, and billing.

Every owned record carries `business_account_id`. Every external Meta object is
linked through stable identifiers. Webhook ingestion is idempotent, and no Meta
webhook may trigger a duplicate AI reply, booking, follow-up, or alert.

The detailed owned-product boundary, runtime services, status mappings, and draft PostgreSQL schema are defined in `TECHNICAL_DESIGN.md`. Canonical product terminology is defined in `CONTEXT.md`.

## 22. Product Principle

The AI's purpose is not to maximize conversation length. Its purpose is to help the lead, determine fit, and move only genuinely ready buyers to the right human with enough context for that human to act immediately.


## 12 September scope extension

The approved agreement defines guided setup, authoritative Offer prices/promotions, managed AI provider ownership, manual subscriptions and usage, ad-set routing, templates/broadcasts, optional paid consultation, model benchmarking, and final acceptance across different business types. See ADR 0016 and the R19–R28 issue manifest. Example prices are not published tariffs.
