# Highly Qualified Handoff and WhatsApp Alert

## What to build

When a Lead becomes Highly Qualified, create a safe human handoff, assign the
configured Human Operator, and immediately send a useful WhatsApp alert. Leads
who merely demand a human must continue with the AI unless the qualification
rules permit handoff.

## Acceptance criteria

- [x] Only a Lead with the required Highly Qualified evidence can trigger the automatic sales handoff.
- [x] An unqualified Lead requesting a human receives the configured explanation and qualification continues without a handoff.
- [x] The handoff cancels all pending AI replies before assigning the Human Operator.
- [x] Alert recipients are configurable by alert type and can include the assignee and admin.
- [x] The alert includes full contact details, business type, problem, lead volume, urgency, budget signal, decision authority, qualification reasons, and an owned inbox Conversation link.
- [x] The operator can assign or reassign the Lead, and reassignment is audited.
- [x] Retried events create only one logical handoff and one alert per configured route.
- [x] A qualified but non-urgent Lead remains available for follow-up without automatic booking or urgent handoff.

## Blocked by

- Ticket 003: One-question-at-a-time lead qualification.

## Implementation notes

- Added durable `LeadHandoff` records keyed by Business Account, Conversation,
  Qualification, and alert type so retried events reuse one logical sales
  handoff.
- Added `AiLeadEmployee::HighlyQualifiedHandoffService` to assign the configured
  Human Operator, invalidate pending AI replies through `control_version`, and
  store WhatsApp alert recipients and delivery attempts.
- Added account settings support for `ai_lead_employee.human_operator_id`,
  `ai_lead_employee.alert_routes.highly_qualified_sales_handoff`, and
  `ai_lead_employee.unqualified_human_request_explanation`.
- Added direct reassignment audit rows for Conversation assignee changes without
  importing Enterprise audit code.
