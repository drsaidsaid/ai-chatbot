# Incomplete-Lead Follow-Up and Opt-Out

## What to build

Follow up with a Lead who stops responding during qualification using the point
where the conversation stopped. Timing and limits must be configurable. A clear
opt-out, closure, or human takeover must prevent further automated follow-up.

## Acceptance criteria

- [ ] An admin can configure follow-up timing, maximum attempts, and enablement by offer or stage.
- [ ] An incomplete qualification schedules one follow-up based on the last unanswered useful question.
- [ ] Qualified Leads may receive an optional second follow-up only when configured.
- [ ] Human takeover, pause, resolution, booking, or opt-out cancels incompatible scheduled actions.
- [ ] Clear opt-out language immediately records consent withdrawal and prevents all automated follow-up.
- [ ] A late or retried scheduled job rechecks durable Control State and opt-out state before sending.
- [ ] Operators can see pending, sent, cancelled, and failed follow-ups with their reasons.
- [ ] Automated time-based checks cover cancellation races and duplicate execution.

## Blocked by

- Ticket 003: One-question-at-a-time lead qualification.
