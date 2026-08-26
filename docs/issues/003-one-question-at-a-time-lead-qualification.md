# One-Question-at-a-Time Lead Qualification

## What to build

Qualify a Lead naturally across WhatsApp while answering relevant questions and
asking at most one useful qualification question at a time. Store evidence for
business type, problem, lead volume, urgency, budget, decision authority, and
contact details. Keep Lead Quality separate from Follow-up State and allow an
authorized human to correct extracted facts.

## Acceptance criteria

- [x] An admin can configure, reorder, edit, enable, and disable qualification questions and budget ranges.
- [x] The AI asks one unanswered question at a time and does not repeat facts already provided or remembered.
- [x] Lead Quality is one of Unknown, Unqualified, Low Qualified, Qualified, or Highly Qualified.
- [x] Highly Qualified requires current evidence for pain, budget, urgency, and decision authority.
- [x] Every quality decision stores its score, reasons, missing signals, evidence, and configuration version.
- [x] A human edit supersedes prior extracted evidence and triggers a consistent re-evaluation.
- [x] A returning Lead retains identity and history but can be reclassified from new evidence.
- [x] Unqualified and qualified-but-non-urgent examples are classified without creating a call booking.
- [x] The operator view shows contact details, extracted facts, quality, reasons, and the next intended question.

## Implementation notes

- Added owned qualification configuration, budget range, evidence, and Lead
  Qualification records scoped by Business Account.
- Added a deterministic qualification service that extracts current evidence,
  scores Lead Quality separately from Follow-up State, records reasons and
  missing signals, and returns the next enabled unanswered question.
- Wired inbound Meta WhatsApp text replies to answer from approved knowledge and
  then ask the next qualification question.
- Added APIs for admin qualification configuration and Human Operator evidence
  correction, with human evidence superseding prior extracted facts.
- Exposed qualification facts, quality, reasons, and next question in the
  existing AI Employee conversation sidebar.

## Blocked by

- Ticket 002: Approved answers and unsupported media.
