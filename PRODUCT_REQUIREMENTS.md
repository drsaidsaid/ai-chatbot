# AI Lead Employee

## Product Requirements Document

**Status:** Revised for owned-inbox v1 implementation
**Revision:** 3 (2026-08-25)
**Working product name:** AI Lead Employee  
**Initial channel:** WhatsApp  
**Initial customer:** Our own online education and AI employee services business  
**Delivery model:** Done-for-you service  

## 1. Product Summary

AI Lead Employee is a WhatsApp-based AI employee that receives incoming lead messages, answers approved business and offer questions, qualifies each lead, books calls with highly qualified leads, and alerts the right human with a concise explanation of why the lead deserves immediate attention.

The product exists so the business owner and sales team spend their time speaking to qualified buyers instead of manually answering every inquiry.

The first version will be built and tested internally. Once it performs reliably, it can become a done-for-you service for businesses with high WhatsApp inquiry volume and valuable customers, initially considering clinics, real estate businesses, and other high-ticket service providers.

## 2. Product Goal

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

- Direct Meta WhatsApp Business Cloud API integration.
- An owned inbox frontend and backend derived from the Community Edition source.
- First-party AI-to-human handoff, qualification panel, and operational queues.
- First-party user authentication, role management, and tenant-scoped database.
- AI replies to inbound text messages.
- Approved FAQ, offer, pricing, objection, and policy knowledge.
- Configurable qualification questions and rules.
- Lead extraction, scoring, and classification.
- Automatic booking for highly qualified leads.
- Connected calendar availability plus custom booking hours.
- WhatsApp alerts to configurable human recipients.
- Shared dashboard inbox and lead list.
- Per-conversation AI pause, human takeover, and manual resume.
- Team assignment and basic roles.
- Human review of unanswered or sensitive questions.
- Approval-based knowledge improvement.
- Follow-up messages for incomplete conversations.
- Basic analytics, testing tools, audit history, CSV export, and manual lead import.
- Saved operational queues using owned labels, priorities, snoozing, and filters.
- Human macros and canned responses for common manual actions.
- Click-to-WhatsApp advertisement attribution when Meta referral data is available.
- Business-hours-aware human handoff messaging.
- Optional WhatsApp Business app coexistence when supported by Meta and the connected account.

### Not Included

- Facebook Messenger or Instagram Direct integration.
- YouTube or TikTok message handling.
- A self-service customer onboarding product.
- Automatic understanding or transcription of voice notes.
- Deep interpretation of images, documents, or other media.
- Cross-channel identity matching.
- Google Sheets synchronization.
- Fully autonomous custom pricing, refunds, legal advice, or medical advice.
- Guaranteed sales or revenue claims.
- Chatwoot Enterprise features or code requiring a commercial license.

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

A team member can:

- View and respond to assigned leads only.
- Receive alerts for assigned leads.
- Edit details and add private notes on assigned leads.
- Take over an assigned conversation.
- Request that a human answer be considered for the knowledge base.

All human messages are sent through the same WhatsApp business number. The first human message may optionally introduce the team member by name.

## 5. Lead Data Model

Every record must include a hidden `business_account_id` from the beginning, even though v1 serves one internal business. This prepares the system for future multi-client use without exposing multi-client controls in the initial interface.

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

- **Unknown:** Not enough information has been collected.
- **Unqualified:** The person has no relevant business, is outside the target audience, has no realistic ability or intention to pay, only seeks free advice, or clearly does not need the service.
- **Low Qualified:** The person generally fits the target audience but is missing at least one major buying signal: meaningful pain, budget, or urgency.
- **Qualified:** The person fits the target audience and has a plausible need and ability to buy, but immediate readiness, authority, or urgency is incomplete.
- **Highly Qualified:** The person has a relevant and urgent problem, sufficient budget, decision-making authority, and enough contact information for immediate action.

### Follow-up State

- No follow-up needed.
- Needs nurture.
- Needs human review.
- Call booked.
- Closed.

These values are configurable by an admin in a future version. V1 should preserve these fixed system meanings so reports and automation remain dependable.

## 7. Qualification Framework

The system uses both hard rules and a configurable score.

### Hard Rules

- No business or relevant professional activity means unqualified.
- A highly qualified lead must have all three of the following: urgent pain, sufficient budget, and decision-maker authority.
- The agent must not book a sales call automatically unless the lead is highly qualified.
- Name and WhatsApp number are required before a lead is considered ready for human handoff.
- Business name and location are strongly preferred but may not block handoff when all major buying signals are strong.
- Email is optional.

### Scoring Signals

The configurable score should consider:

- Fit with the target customer profile.
- Severity and relevance of the problem.
- Inquiry or lead volume.
- Urgency.
- Budget range and confidence.
- Decision-making authority.
- Willingness to proceed.
- Contactability.

Hard rules always override the numerical score. The system must store both the score and a plain-language qualification explanation.

### Default Qualification Questions

The admin can add, remove, edit, and reorder questions by offer. Default questions are:

1. What kind of business do you run?
2. What problem are you trying to solve with your leads or messages?
3. Roughly how many inquiries do you receive per day or month?
4. How soon would you like this problem solved?
5. To help me recommend the right setup, what monthly budget range have you set aside for improving this?
6. Are you the person who decides on this, or is someone else involved?

Default budget options:

- Below TZS 200,000 per month.
- TZS 200,000-500,000 per month.
- TZS 500,000-1,000,000 per month.
- Above TZS 1,000,000 per month.

The agent should ask one question at a time. It may combine only questions that are naturally inseparable.

## 8. Conversation Behavior

### Tone

The agent acts as a warm business advisor: friendly, brief, respectful, professional, and focused on diagnosis. It should sound natural without pretending to be a specific human.

### Conversation Rules

- Answer relevant questions briefly using approved knowledge.
- Ask one useful qualification question after answering.
- Do not repeat questions already answered in the current conversation or remembered lead history.
- Extract answers even when the lead provides several details in one message.
- Continue from the point where an interrupted conversation stopped.
- Do not interrogate the lead or expose internal scoring rules.
- Do not claim that a human will call unless the lead is highly qualified and a handoff or booking is actually being created.
- Redirect immediately when a lead asks about topics outside the business or service.
- Never invent an answer when approved knowledge is insufficient or conflicting.

### Question Debt Rule

The agent may answer up to two consecutive lead questions without receiving a qualification answer. It must then gently return to qualification before continuing with more detailed answers.

Suggested wording:

> Good question. I can explain that, but first I need to understand your business a little so I do not give you the wrong answer. What type of business do you run?

### Requests for a Human

If the lead asks for a human before qualifying, the agent explains that specialists prioritize businesses ready to use the service and offers to continue answering relevant questions while completing qualification.

Suggested wording:

> Our specialists prioritize businesses that are ready to set this up soon. I can still answer your questions here and help you understand whether it is a fit.

The agent must not create a human handoff merely because an unqualified lead insists.

### Out-of-Scope and Sensitive Topics

The agent must escalate instead of improvising on:

- Legal or medical advice.
- Guarantees or promises of results.
- Exact custom pricing.
- Refund decisions.
- Private company information.
- Questions outside the business or offered services.

### Voice Notes and Media

- Voice notes are stored and visible to humans.
- The AI replies: "I could not listen to your audio. Please send your message as text."
- Other media is stored and flagged for human review.
- V1 does not deeply interpret voice notes or attachments.

### Opt-Out

The system must recognize clear opt-out requests such as "stop messaging me," stop automated follow-up immediately, and record the opt-out status.

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

## 10. Booking

Only highly qualified leads are automatically offered a call in v1.

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

The admin can configure weekdays, weekends, and time windows. The initial internal default should block mornings and permit calls from 12:00 to 17:00, subject to calendar availability.

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

- Leads have a default owner.
- An admin may manually assign or reassign any lead.
- V1 supports automatic assignment structure, initially default-owner based, with future rules for round-robin, offer, and availability.
- The assigned human receives the direct WhatsApp alert; the admin may be copied on high-priority alerts.
- Reassignment remains possible after booking and must be recorded in the audit history.
- When a human sends a reply, the AI pauses automatically for that conversation.
- A human assignment, handoff, pause, reply, or resolution cancels any pending AI reply before it can be sent.
- Before every outbound AI message, the system must recheck that the AI still owns the conversation; an already-queued reply must be blocked after human takeover.
- The AI resumes only when a human explicitly resumes it.
- Resuming the AI does not immediately send a message; it permits the next eligible lead message or scheduled action to be evaluated.
- Internal notes are never sent to the lead.

## 13. Follow-Up

The system follows up when a lead stops responding before qualification is complete.

- Default first follow-up: 24 hours after the last unanswered agent question.
- Timing is configurable to allow testing alternatives.
- The message is based on where the conversation stopped.
- Maximum one automated follow-up for incomplete qualification.
- An optional second follow-up is allowed only for qualified leads.
- No follow-up is sent after opt-out, closure, or human takeover unless a human explicitly schedules it.

## 14. Dashboard Requirements

### Inbox

- The owned inbox displays all permitted conversations in a familiar messaging layout.
- Filters for quality, follow-up state, assignee, source, unanswered questions, and booking status.
- Search by name, phone number, business, or message text.
- Visible AI/human control state.
- Reply, pause, resume, assign, and add-note actions.
- Saved queues for hot leads, human review, follow-up due, and booked calls.
- Canned responses and macros for human operators.

### Leads

- Table of contact details, quality, score, source, assignee, last activity, and next action.
- Editable extracted fields.
- Clear qualification explanation and missing signals.
- CSV export and manual lead import.

### Hot Leads

- Prioritized list of highly qualified leads and booked calls.
- Qualification reasons and contact details visible without opening each conversation.

### Human Review

- Unanswered questions.
- Sensitive or conflicting requests.
- Angry or urgent conversations.
- Correct-answer entry and send action.

### Knowledge

- FAQ, offer details, pricing, objections, policies, and supporting documents.
- Draft, approved, and rejected states.
- Source priority and conflict visibility.
- Approval workflow for human answers.

### Configuration

- Offers and target customer profiles.
- Qualification questions, hard rules, scoring, and budget ranges.
- Booking hours and connected calendar.
- Alert recipients and alert types.
- Team members and assignments.
- Follow-up timing and message rules.
- Sandbox/test mode.

### Analytics

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

Campaign information should be stored whenever it is available. Campaign-specific reply behavior is deferred until after the core qualification flow is reliable.

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

The initial commercial model is a done-for-you package comprising:

- One-time setup and business configuration.
- Ongoing monthly monitoring and optimization.
- A monthly included conversation allowance.
- Usage-based overage priced by conversation, not individual message.

Initial internal pricing hypothesis:

- Setup: TZS 500,000-1,000,000.
- Monthly service: TZS 200,000-500,000.
- Final price varies by inquiry volume, setup complexity, and supported channels.

The agent may share a rough approved range but must explain that exact pricing depends on the business's volume and needs.

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
- Exact scoring weights and minimum score thresholds.
- Exact included conversation allowances and overage prices.
- WhatsApp Business account and number used for the pilot.
- Calendar provider used for the first integration.
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
