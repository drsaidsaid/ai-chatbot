# Incomplete-Lead Follow-Up and Opt-Out

## What to build

Follow up with a Lead who stops responding during qualification using the point
where the conversation stopped. Timing and limits must be configurable. A clear
opt-out, closure, or human takeover must prevent further automated follow-up.

## Acceptance criteria

- [x] An admin can configure follow-up timing, maximum attempts, and enablement by offer or stage.
- [x] An incomplete qualification schedules one follow-up based on the last unanswered useful question.
- [x] Qualified Leads may receive an optional second follow-up only when configured.
- [x] Human takeover, pause, resolution, booking, or opt-out cancels incompatible scheduled actions.
- [x] Clear opt-out language immediately records consent withdrawal and prevents all automated follow-up.
- [x] A late or retried scheduled job rechecks durable Control State and opt-out state before sending.
- [x] Operators can see pending, sent, cancelled, and failed follow-ups with their reasons.
- [x] Automated time-based checks cover cancellation races and duplicate execution.

## Blocked by

- Ticket 003: One-question-at-a-time lead qualification.

## Implementation notes

- Added durable `LeadFollowUp` and `LeadFollowUpOptOut` records scoped by
  Business Account, Lead, Conversation, qualification, question, stage, attempt,
  control version, and delivery state.
- Added configurable follow-up timing and attempt limits in account settings
  under `ai_lead_employee.follow_up`.
- Added scheduler, delivery job, delivery service, and opt-out service checks so
  late retries re-read Control State and opt-out state before sending.
- Added cancellation hooks for human takeover, pause, closure, assignment,
  booking, and terminal follow-up states.
