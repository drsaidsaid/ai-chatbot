# One-Question-at-a-Time Lead Qualification

## What to build

Qualify a Lead naturally across WhatsApp while answering relevant questions and
asking at most one useful qualification question at a time. Store evidence for
business type, problem, lead volume, urgency, budget, decision authority, and
contact details. Keep Lead Quality separate from Follow-up State and allow an
authorized human to correct extracted facts.

## Acceptance criteria

- [ ] An admin can configure, reorder, edit, enable, and disable qualification questions and budget ranges.
- [ ] The AI asks one unanswered question at a time and does not repeat facts already provided or remembered.
- [ ] Lead Quality is one of Unknown, Unqualified, Lowly Qualified, Qualified, or Highly Qualified.
- [ ] Highly Qualified requires current evidence for pain, budget, urgency, and decision authority.
- [ ] Every quality decision stores its score, reasons, missing signals, evidence, and configuration version.
- [ ] A human edit supersedes prior extracted evidence and triggers a consistent re-evaluation.
- [ ] A returning Lead retains identity and history but can be reclassified from new evidence.
- [ ] Unqualified and qualified-but-non-urgent examples are classified without creating a call booking.
- [ ] The operator view shows contact details, extracted facts, quality, reasons, and the next intended question.

## Blocked by

- Ticket 002: Approved answers and unsupported media.
