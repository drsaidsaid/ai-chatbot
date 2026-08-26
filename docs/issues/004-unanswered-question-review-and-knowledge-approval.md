# Unanswered-Question Review and Knowledge Approval

## What to build

When the AI Employee cannot answer safely, create a Human Review Request, notify
the configured recipient, and keep the lead informed without fabricating. Let a
Human Operator answer the specific lead and then decide whether that answer should
be proposed as reusable knowledge in a selected category.

## Acceptance criteria

- [x] An unknown, conflicting, sensitive, or blocking question creates one deduplicated Human Review Request.
- [x] Configured recipients receive a WhatsApp alert and the request appears in the operator queue.
- [x] A Human Operator can answer the lead in the same owned inbox Conversation.
- [x] Human activity safely takes control and blocks pending AI replies.
- [x] After answering, the operator is asked whether to propose the answer for future use and to select its category.
- [x] Proposed knowledge remains unavailable to the AI until explicitly approved.
- [x] Resolution links the review request, human answer, lead message, and optional knowledge proposal.
- [x] Similar future questions use the approved answer without exposing private conversation content.

## Implementation progress

- Added tenant-scoped Human Review Requests linked to the Conversation, lead message, human answer, optional proposed Knowledge Item, alert recipients, and alert delivery attempts.
- Added review-request creation from unanswered, conflicting, sensitive, angry, and qualification-blocking WhatsApp messages, with deduplication by Business Account, Conversation, lead message, and reason.
- Sends configured WhatsApp review alerts through the owned Meta Cloud API credentials and keeps the Lead informed with the boundary response rather than fabricating.
- Moves Conversations with open review requests into Handoff Requested after the AI Employee sends its safe reply, so later automated work is invalidated by Control State.
- Added an account-scoped Reviews API and owned workspace panel where Human Operators can find open review requests, link a human-sent answer, and optionally propose a draft Knowledge Item category.
- Draft knowledge proposals remain unavailable to the AI Employee until the existing Knowledge approval flow approves them.

## Blocked by

- Ticket 002: Approved answers and unsupported media.
