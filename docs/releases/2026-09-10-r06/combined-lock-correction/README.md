# R06 combined Account-lock correction

Correction commit: `dd49ef996b1b9e0cb1f9e5c9b356bf781e06b21f`.
The final serial check passed 20 examples with zero failures in 20.26 seconds
after a 13.61-second Rails load, using `LOG_LEVEL=warn`. Deadlines are unchanged.
Both Ruby files and normal commit hooks passed. Independent coordinator
Standards and Spec reviews of `842ef46...dd49ef9` both returned zero findings.
The heavy-check slot is released.

The accepted local browser evidence remains at runtime
`323d381291a51ae573e0f840cec12dab2d0784bc` and evidence tip
`842ef4663d73aaa3528e8a3d9d2929823393e16f`. Its fixture and evidence files
are preserved. A subsequent review of combined tree `f2dc31d4` found a database
lock interaction between membership cleanup and R04 operator-review creation.

Cleanup held the Account `FOR UPDATE` lock before unassigning Conversations.
R04 `OutboundDispatch#unknown!` and `OutboundDelivery#recover!` hold a Conversation
lock while `record_unknown!` inserts a HumanReviewRequest. That insert's real
Account foreign key requires `FOR KEY SHARE`, producing a circular wait:
cleanup owns Account and waits for Conversation; review creation owns Conversation
and waits for Account.

The correction changes only cleanup's Account lock strength to
`FOR NO KEY UPDATE`, retaining the membership recheck and every cleanup mutation
inside the transaction. It still conflicts with AgentBuilder's `FOR UPDATE`
invitation lock, but permits Account foreign-key checks. The compatibility is
documented in PostgreSQL's [row-lock matrix](https://www.postgresql.org/docs/current/explicit-locking.html#LOCKING-ROWS).

## Regression boundary

The new third example in `r06_membership_cleanup_concurrency_spec.rb` uses two
independent database connections. One holds the actual Conversation row lock.
The other runs the actual DestroyJob. A bounded `pg_blocking_pids` barrier waits
until cleanup reaches the locked Conversation; the first connection then creates
a real HumanReviewRequest through its Account foreign key. Success requires the
review to persist and cleanup to unassign the Conversation and remove that
account's notification setting. The other account's settings and assigned
Conversation access must remain unchanged.

The R06 branch does not contain R04 delivery classes or its `delivery_unknown`
enum. This regression uses the shared HumanReviewRequest model's `provider_failed`
reason to exercise the same physical Account foreign key and Conversation lock.
It does not claim to call R04's dispatch service. Exact R04 sources from combined
tree `f2dc31d4` were read without modifying that checkout and are hashed in
`combined-source-sha256.json`. Provider delivery is not invoked.

Before the correction, the new example failed with `ActiveRecord::Deadlocked` /
`PG::TRDeadlockDetected`. PostgreSQL reported reciprocal waits between processes
53902 and 51036 and aborted cleanup's Conversation update. This is an actual
deadlock, not a barrier timeout. The run took 95.53 seconds after a 5m26s Rails
load on the busy local host. An earlier setup-only run stopped on a dirty fixture
`display_id`; reloading before locking corrected that setup, and that earlier
failure is not counted as deadlock evidence.

The serial green run includes this regression, both existing cleanup/invitation
ordering proofs, invitation requests, AccountUser callbacks, cleanup jobs and
notification-settings controller checks. Final results and commit provenance
are recorded in `checks.json`. The first green attempt was stopped at the
coordinator's request during the shared frontend build's memory pressure and is
not counted as a result. The accepted green run followed the explicit exclusive
check-slot grant after that build completed.

No frontend inputs, schema, browser fixture, provider settings or combined
checkout were changed. No additional build, browser run or real delivery is
needed for this lock-strength correction. The coordinator owns independent
review and combined integration.
