# Evaluation Sandbox and Launch Gate

## What to build

Give admins a safe way to simulate WhatsApp conversations, inspect every AI
decision, grade results, and control whether live AI operation is enabled. The
launch gate must combine automated scenarios, team roleplay, and reviewed pilot
conversations rather than relying on anecdotal success.

## Acceptance criteria

- [ ] An admin can run a test Conversation without sending a real WhatsApp message.
- [ ] Each step shows the selected answer, sources, extracted evidence, Lead Quality, score, next question, handoff decision, and booking decision.
- [ ] Reusable scenarios cover all primary PRD acceptance scenarios, including duplicate events and a late AI job after takeover.
- [ ] Reviewers can grade answer correctness, qualification correctness, tone, safety, and next action.
- [ ] Results report qualification accuracy, handoff accuracy, unanswered-question rate, booking outcomes, and serious safety failures.
- [ ] Live AI operation cannot be enabled until required checks are complete and an admin records approval.
- [ ] The launch report confirms at least 85-90% reviewed qualification accuracy and zero serious fabricated, harmful, or policy-breaking answers.
- [ ] The system records the configuration and knowledge versions used by every evaluated decision.

## Blocked by

- Tickets 002-008.
