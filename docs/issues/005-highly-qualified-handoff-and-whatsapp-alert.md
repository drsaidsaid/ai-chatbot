# Highly Qualified Handoff and WhatsApp Alert

## What to build

When a Lead becomes Highly Qualified, create a safe human handoff, assign the
configured Human Operator, and immediately send a useful WhatsApp alert. Leads
who merely demand a human must continue with the AI unless the qualification
rules permit handoff.

## Acceptance criteria

- [ ] Only a Lead with the required Highly Qualified evidence can trigger the automatic sales handoff.
- [ ] An unqualified Lead requesting a human receives the configured explanation and qualification continues without a handoff.
- [ ] The handoff cancels all pending AI replies before assigning the Human Operator.
- [ ] Alert recipients are configurable by alert type and can include the assignee and admin.
- [ ] The alert includes full contact details, business type, problem, lead volume, urgency, budget signal, decision authority, qualification reasons, and a Chatwoot conversation link.
- [ ] The operator can assign or reassign the Lead, and reassignment is audited.
- [ ] Retried events create only one logical handoff and one alert per configured route.
- [ ] A qualified but non-urgent Lead remains available for follow-up without automatic booking or urgent handoff.

## Blocked by

- Ticket 003: One-question-at-a-time lead qualification.
