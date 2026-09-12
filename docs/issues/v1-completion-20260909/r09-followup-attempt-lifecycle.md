# R09 follow-up attempt and lifecycle increment

Status: implementation candidate; blocked on complete frozen verification and
independent source review. No whole-R09 or release acceptance yet.

Blocker decision: accepted ADR0015 and accepted increment1 e134 source.

One configured follow-up attempt no longer resets when its Offer changes. A
never-admitted stale artifact can have one current linked successor under the
same budget. Its content, origin, question and decision remain historical facts.
An admitted, uncertain, failed or blocked attempt cannot be recycled.

Implemented migration17, conservative history, scheduler/materializer ownership,
atomic A/D admission, projection-only publication, accepted/unknown/failure/
preparation/recovery/repair/retry owners, batch control/consent/callback cancellation
and M-only status projection. Legacy changed-question input is retained with
explicit history-preserving cancellation assertions; unchanged legacy scheduling,
timing rescheduling and actual once-only delivery pass. Normal human retry stays
supported; automated follow-up attempts cannot reset consumed admission.

Actual development evidence:12/12 initial frozen red;27/0 frozen scheduling seam;
8/7 frozen outcome red;33/0 outcome implementation;17/0 initial worker matrix.
Additional frozen reds prove historical empty-source misclassification, multi-
Conversation callback rank inversion, stale A/B Offer-union deadlock, late missing
authority discovery, and implicit existing-budget lock ordering. Their fixes and
all focused checks now run67/0 including24 committed worker interleavings.
The wider147/1 run had only the legacy delivery cancellation-code regression;
restoring `follow_up_canceled` while keeping F's detailed reason passed targeted7/0.
These are separate development runs, not one combined green claim.

Complete frozen combined verification follows in
`docs/releases/2026-09-11-r09-followup-lifecycle/`. No Vue/R07 controls, build,
lint, hooks, commits, live provider call or deployment is part of this interval.
