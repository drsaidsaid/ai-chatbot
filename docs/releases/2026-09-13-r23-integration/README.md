# R23 combined integration verification — in progress

Base: fbee83c96afa58ab1610a0f480b34eb04b1e5ef8 (accepted R09).
Candidate: db255c4bae90a3a613e1d08341180dde52978155 (R23 evidence tip).
Acceptance is complete locally; normal merge commit/hooks, push and issue closure remain. No deployment.

The combination preserves R09 Offer authority and delivery lifecycle plus R23
logical reply reservations, receipt-based settlement, and manual finance controls.
Review corrections serialize receipt evidence against partial closure and manual
release, acquire subscription alert authority before deliveries, cap direct alert
retries, and execute retries outside the alert service lock. Deterministic tests
prove receipt-first and closure-first outcomes, including a real database lock wait.

R09 already owns migration20260912000100. The four unintegrated R23 migrations
are renamed00600/00700/00800/00900 in their original order; bytes are unchanged.
R26 retains00400. Historical candidate evidence remains unchanged.

## Results

- Fresh combined schema load passed in newly created, isolated local database
  `ale_r23_combined_20260913_spec`, role `ghalyasaid`, localhost5432.
- 38 focused examples passed after final alert-lock correction, including the two
  deterministic receipt-order tests and direct alert retry ceiling regression.
- Additional affected authority/provider/outbound suite:118 examples,2 failures.
  Both failures were Test Center evaluations: these correctly do not reserve
  customer credits, but the combined code unconditionally tried registering a
  nil reservation. Registration is now conditional on an actual reservation.
- All11 tests in the affected provider-usage suite passed after this correction;
  new assertions prove evaluations create no customer reply usage records.
- Changed Ruby/style checks passed at their recorded checkpoints; final hook
  verification remains required after all integration preparation.
- Both independent reviewers cleared the lock/qualification/billing corrections;
  the final one-line evaluation registration guard also cleared bounded re-review.

The nontransactional ordering suite permits cleanup only in the exact dedicated
R23 database with explicit `R23_COMMITTED_FIXTURES=yes`. No shared/default test
or production database is used. Provider calls in these suites use existing
WebMock test boundaries, not live customer sends.

## Still required

Normal merge commit/hooks, evidence verification, push and issue closure.
Forward upgrade and combined frontend/build/browser acceptance now passed as recorded below.


## Forward upgrade check

A second newly created dedicated database, `ale_r23_upgrade_20260913_spec`, was
loaded from the exact accepted fbee83c9 schema. A synthetic existing Account
was inserted, then normal Rails migrations applied00600–00900 successfully.
The existing Account survived, and the migration ledger contains accepted00100
plus00600/00700/00800/00900. No historical full migration replay was attempted.
The checked-in combined schema is now the actual resulting Rails dump. This
removes a stray `expected_delivery_parts` column from the provider-usage table
that existed only in the candidate schema, not its migrations; logical reply
usage retains its intended expected-delivery-parts field and constraint.
