# R07 current-review evidence

## Scope

This note covers the current candidate only. It records the resume boundary,
canonical WhatsApp ingress ordering, and unsupported-media review admission. It
does not claim a provider-arrival ordering guarantee: the boundary begins at the
application's canonical Message persistence transaction.

## Baseline observation

The accepted baseline was reproduced before the current candidate changes. Four
unrelated focused failures were already present: three notification expectations
and one automated-contact-consent fixture with no Lead. They were not modified
by this work.

## Current proof

- `Conversation#ai_resume_after_message_id` is captured while the Conversation
  is locked.
- Canonical WhatsApp regular, unsupported, and contacts persistence takes the
  same Conversation lock for the final Message save. Attachment preparation and
  downloads occur before it.
- Durable ingress defers existing-contact identifier and profile mutation until
  it holds the Conversation lock, preserving Channel → Conversation → Contact
  ordering with qualification work.
- The delayed/replayed unsupported-media path applies the same locked AI-active,
  open, unassigned, launch-gate, and resume-boundary checks as text ingress.

## Bounded verification

- Resume/persistence and ingress/qualification PostgreSQL ordering suite:
  3 examples, 0 failures. It asserts real lock waits through
  `pg_blocking_pids`, including both resume orders and the Channel → Conversation
  → Contact interleaving.
- Recorder, control, persistence-order, and existing profile-update checks:
  25 examples, 0 failures.
- Direct coexistence echo versus queued `SendReplyJob` authorization: 1 example,
  0 failures. A PostgreSQL trigger pauses direct echo persistence after it owns
  the transaction; the queued dispatch blocks, then observes the committed Human
  Operator takeover and canceled delivery without a provider request.
- Direct echo plus ingress/resume, recorder, and control regression run:
  23 examples, 0 failures. Together with the direct echo proof, this later
  bounded run completed 24 examples with 0 failures.
- Ruby syntax and staged whitespace checks passed.
- Conversation pagination regression: 77 focused Vue store mutation examples,
  0 failures; ESLint passed for the store mutation and its spec. The regression
  covers a reload page returning messages already present in the active window.
  `SET_PREVIOUS_CONVERSATIONS` now deduplicates by durable Message ID before it
  prepends the older page.
- Cockpit booking-timezone and suggested-action regressions: 5 Ruby examples,
  0 failures. A booking instant is formatted in its declared timezone; an open
  Review Request remains actionable even when automated contact is stopped.
- Cockpit Vue regression suite: 23 examples, 0 failures. It asserts that the
  booked-time display uses the booking timezone rather than the browser timezone.

## Isolated browser fixture

The disposable browser database is `ale_r07_browser_current_20260913`, guarded
by `RAILS_ENV=test`, `ALE_R07_BROWSER_CURRENT=1`, and localhost PostgreSQL. It
contains only synthetic data. Additive scenario conversation display IDs are:

- `3`: a confirmed synthetic booking for Bina Booking, with a qualified Lead,
  one qualification evidence row, and the second synthetic operator assigned.
- `4`: Pendo Pending with one pending orchestration intent and linked pending
  outbox event, for cancellation checks without a provider call.
- `5`: Omar Opt Out with a Lead-authored `STOP` message and explicit opt-out
  record.

## In-app browser acceptance

Acceptance used the in-app browser only, against production-built assets and
the isolated fixture. It covered desktop and a `390 × 844` viewport, with no
horizontal page overflow. The checked flows were contact identity and assignee
display, Review versus Booking presentation, pause/resume, human assignment and
reassignment, public reply versus private note persistence, stale-intent
cancellation, keyboard activation, resolution, and the resume boundary.

The confirmed booking displays the same instant in both surfaces: Jan 8, 2030
at 1:00 PM Africa/Dar_es_Salaam and 13:00 local time. The explicit-opt-out
scenario retains its stopped banner and `Automated contact stopped` next action
through pause and resume; an open Review Request takes precedence when present.

The pagination regression was retested through the mobile resolve flow and
rendered each durable message once. No provider request was made.

## Production asset builds

- `/tmp/r07-build-20260919-4gb.log`: production Vite build completed with a
  manifest containing 232 entries and no missing assets.
- `/tmp/r07-dedup-build-20260919.log`: production Vite rebuild completed after
  the pagination fix.
- `/tmp/r07-timezone-build-20260919.log`: production Vite rebuild completed
  after the booking-timezone and opt-out action corrections.

The isolated browser runtime used no external provider configuration. The
candidate is committed after the evidence and staged checks are complete.
