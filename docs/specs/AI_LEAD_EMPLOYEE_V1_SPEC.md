# AI Lead Employee V1 Specification

**Status:** Build ready  
**Planning map:** GitHub issue #1  
**Product boundary:** Owned Community Edition fork, direct Meta WhatsApp Cloud
API, no Chatwoot service or Enterprise source

## Problem Statement

Business owners receive too many WhatsApp inquiries to answer, diagnose, and
follow up with personally. They need an AI Employee that handles ordinary
questions, qualifies each Lead naturally, and brings only the right people to a
Human Operator's attention without losing context or sending unsafe replies.

## Solution

AI Lead Employee is a branded, owned WhatsApp lead-operations workspace. It
receives Meta messages directly, persists them in an owned inbox, answers only
from approved Knowledge Items, asks one qualification question at a time, and
maintains separate Qualification, Follow-up State, Control State, and Inbox
Conversation Status. It alerts and books calls only when a Lead is Highly
Qualified. A Human Operator can take over, pause, correct, or resume safely at
any time.

## User Stories

1. As a Lead, I want a prompt, helpful WhatsApp reply so that I receive useful
   information without waiting for a person.
2. As a Lead, I want the AI Employee to answer relevant questions before asking
   for qualification details so that the conversation feels respectful.
3. As a Lead, I want one qualification question at a time so that I can answer
   naturally on WhatsApp.
4. As a Lead, I want the conversation to remember my prior messages so that I
   do not need to repeat known information.
5. As a Lead, I want a clear, confirmed call time when I qualify so that I know
   when a Human Operator will contact me.
6. As a Lead, I want a template-based follow-up after the WhatsApp service
   window closes so that messages remain compliant with WhatsApp rules.
7. As a Human Operator, I want an owned Inbox showing all WhatsApp
   Conversations so that I can work from one operational workspace.
8. As a Human Operator, I want to see Lead Quality, evidence, the reason for a
   decision, and missing signals so that I can trust or correct the AI Employee.
9. As a Human Operator, I want to claim a Conversation, pause the AI Employee,
   or resume it explicitly so that no automated reply interrupts my work.
10. As a Human Operator, I want a complete Hot Lead alert with contact details,
    pain, urgency, budget signal, and call time so that I can act immediately.
11. As a Human Operator, I want to assign a Conversation and a Hot Lead to a
    teammate so that responsibility is clear.
12. As a Human Operator, I want unresolved or unsafe questions routed to
    Reviews so that an AI Employee never invents an answer.
13. As an admin, I want to approve a Human Operator's answer as Knowledge so
    that future answers improve only with deliberate approval.
14. As an admin, I want to configure Offers, qualification questions, hard
    rules, scoring rules, business hours, availability, and alert recipients so
    that the AI Employee reflects my business.
15. As an admin, I want membership-controlled access so that each Business
    Account's Leads and messages remain private.
16. As an admin, I want to see WhatsApp connection health and delivery states
    so that I can identify provider problems early.
17. As an admin, I want a simulation workspace so that I can test qualification
    changes without contacting a real Lead.
18. As an operator, I want follow-up and opt-out rules applied consistently so
    that the system is persistent without unwanted contact.

## Implementation Decisions

- The owned application is built from the pinned Chatwoot Community Edition
  `v4.17.0` source at the repository root. Preserve the MIT notice and do not
  import, invoke, or distribute Enterprise code.
- The owned Rails backend, PostgreSQL database, Redis queues, Vue inbox, user
  identity, and product API share one application boundary. Meta is the only
  messaging provider in V1.
- The Meta adapter is the sole channel boundary. It verifies GET callback
  challenges and raw-body POST HMAC signatures, records webhook events and
  normalized messages transactionally, and treats outbound delivery status
  webhooks as authoritative.
- A Conversation is the unit of serialized automation. Ownership-changing
  actions increment its `control_version`; every AI or follow-up job locks and
  rechecks Control State, owner, inbox status, and control version before it
  sends.
- An outbound-message decision is persisted with its associated domain change
  and an outbox event. A worker sends it through Meta, stores Meta's message ID,
  and later reconciles `sent`, `delivered`, `read`, or failure status.
- The AI Employee retrieves only approved Knowledge Items. FAQ and Offer
  content override supporting documents. Unknown, conflicting, sensitive,
  angry, and qualified-blocking questions create Review Requests.
- Qualification uses hard rules plus scoring. Lead Quality is only Unknown,
  Unqualified, Low Qualified, Qualified, or Highly Qualified. Highly Qualified
  requires current evidence for pain, urgency, budget, and decision authority.
- The AI Employee asks the configured question sequence one at a time. A Lead's
  relevant question receives a short approved answer, then the AI Employee
  returns to the next needed qualification question.
- Only Highly Qualified Leads receive a Booking and immediate Hot Lead alert in
  V1. Booking checks both connected-calendar availability and the Business
  Account's configured working hours.
- The owned UI exposes Inbox, Hot Leads, Leads, Reviews, Knowledge, Bookings,
  and Settings. Other Community Edition surfaces remain hidden and unsupported.
- Authentication is owned and invite-only. V1 roles are `admin` and
  `team_member`; tenant scope comes from server-verified Business Account
  membership, never a client-supplied identifier.
- The initial environment uses Meta's test number. External onboarding requires
  the production number, a permanent system-user token, App Review, Advanced
  Access, and business verification where Meta requires them.

### Primary Seams

1. **Meta WhatsApp adapter:** accepts verified inbound events and sends owned
   outbound-message intents without exposing provider details to domain logic.
2. **Conversation control service:** owns handoff, assignment, pause, resume,
   resolution, and the final authorization check before automated work.
3. **Qualification service:** accepts normalized evidence and configuration, then
   produces Lead Quality, reasons, missing signals, and the next question.
4. **Knowledge answer service:** returns an approved answer or a Review Request;
   it never returns an unapproved answer to a Lead.
5. **Booking and alert services:** accept idempotent domain commands and create
   durable Booking and Alert records before external delivery.

## Testing Decisions

- Tests validate externally visible behavior and domain invariants rather than
  private implementation steps.
- Contract tests cover Meta callback verification, supported inbound payloads,
  outbound request shape, status normalization, retries, and template fallback
  after the 24-hour customer-service window.
- Transactional integration tests prove duplicate provider events have no second
  logical effect and a late AI job cannot reply after human takeover, pause, or
  resolution.
- Qualification tests cover hard-rule override, score boundaries, evidence
  provenance, one-question progression, returning Leads, manual evidence edits,
  and Highly Qualified requirements.
- Authorization tests prove no user, API request, background job, webhook, or
  search query can cross a Business Account boundary.
- Booking tests cover availability rules, calendar conflicts, idempotent retries,
  confirmation delivery, and optional calendar invite behavior.
- End-to-end staging tests use the Meta test number to confirm verified inbound
  message, owned inbox persistence, controlled outbound reply, and delivery
  status reconciliation.
- Evaluation scenarios cover successful qualification, low-budget Leads,
  unsupported questions, human takeover, audio fallback, opt-out, duplicate
  events, and unavailable booking slots.

## Out of Scope

- Facebook Messenger, Instagram Direct, TikTok, and YouTube.
- Chatwoot-hosted services, Chatwoot credentials, and Enterprise source code.
- Bulk marketing campaigns, customer portal/help center, CRM sync, billing,
  usage metering, self-service client onboarding, voice transcription, calling,
  SAML, social login, custom roles, and complex capacity management.

## Further Notes

- Implement the Community Edition source import before the first production
  ticket; the existing prototype is retained only as repository history.
- Direct Meta production credentials are a later human provisioning task. They
  are not required for unit, integration, or simulation work, but they are
  required for a real WhatsApp round trip.
- The operator experience should be concise and work-focused. Lead Quality must
  never be conflated with Inbox Conversation Status or Follow-up State.
