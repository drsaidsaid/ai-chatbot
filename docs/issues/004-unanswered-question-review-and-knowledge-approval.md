# Unanswered-Question Review and Knowledge Approval

## What to build

When the AI Employee cannot answer safely, create a Human Review Request, notify
the configured recipient, and keep the lead informed without fabricating. Let a
Human Operator answer the specific lead and then decide whether that answer should
be proposed as reusable knowledge in a selected category.

## Acceptance criteria

- [ ] An unknown, conflicting, sensitive, or blocking question creates one deduplicated Human Review Request.
- [ ] Configured recipients receive a WhatsApp alert and the request appears in the operator queue.
- [ ] A Human Operator can answer the lead in the same Chatwoot conversation.
- [ ] Human activity safely takes control and blocks pending AI replies.
- [ ] After answering, the operator is asked whether to propose the answer for future use and to select its category.
- [ ] Proposed knowledge remains unavailable to the AI until explicitly approved.
- [ ] Resolution links the review request, human answer, lead message, and optional knowledge proposal.
- [ ] Similar future questions use the approved answer without exposing private conversation content.

## Blocked by

- Ticket 002: Approved answers and unsupported media.
