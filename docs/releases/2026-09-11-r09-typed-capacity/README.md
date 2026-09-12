> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 typed answers, saved rules and conservative capacity continuations

Intermediate source and evidence at retained ref `refs/r09/typed-capacity-20260911`.
The external frozen-tree.json sidecar is written after freezing and is not part
of its own tree. Full R09 remains incomplete. Prior immutable release evidence
directories are included in this tree; prior retained refs remain unchanged.

## Behavior

Custom money, number, boolean, choice and text answers bind only to the actual
preceding public outgoing question in the same Conversation, Offer and revision.
Outbound metadata now identifies the question key. Explicit facts for a different
field do not also populate the asked custom field. Structured evidence stores
field_key alongside the legacy signal enum; the additive migration backfills
legacy keys and permits custom fields without fabricating enum meanings.

Saved typed rules are validated through the public settings endpoint and evaluated
against the matching Offer evidence. Score weights/rules use nonnegative integers;
hard rules can only exclude. Invalid operators, field types, currencies, choice
values, thresholds and forced upgrades are rejected atomically. A positive numeric
score cannot bypass required buying facts for Qualified or Highly Qualified.
Unknown answers do not match comparisons or repeat their question; an explicit
false boolean can match an explicit false rule without positive presence points.

An adversative financial tail is now retained by default rather than discarded.
Only an anchored replacement budget assertion or a supported independent other-field
statement without financial terms can become a separate candidate. Connector
punctuation is normalized. Remaining ambiguous tails make the budget unknown.
This preserves tested authority/problem uncertainty and explicit budget corrections.
It does not claim universal language understanding.

## Observed evidence

- Typed/rule first red: 19 examples, 17 failures. Initial correction: 19/0.
- Additional typed boundaries: 14 examples, 4 failures. Corrected combined: 33/0.
  The failures were conditional custom money, a score bypass at Qualified and
  loss of choice-list rule values at the public parameter boundary.
- Lifecycle: 13 examples, 2 failures. Human Offer/Conversation edit context and
  field meaning changes after evidence remain unimplemented; no green claim.
- Second capacity review: initial pure-expanded run 32/6 (the actual-Offer fixture
  expansion was interrupted by an assertion in the preparation script). Complete
  pure plus actual Offer expansion: 38/12. Corrected focused: 52/0, including
  previous capacity/allocation cases and the original unchanged HQ job example.
- Final typed plus settings/concurrency/selection compatibility: 49/0.
- Final financial Offer contrasts: 6/0.

Raw outputs are in evidence/. Selected intermediate parser/service files are
archived there; these partial copies are not claimed as complete standalone red
runtimes. The original first typed red runtime is retained in the previous
90cd969 tree. Current complete source has a SHA256 manifest. The original HQ
specification is byte-for-byte unchanged from accepted base 9a834e7.

## Limits and remaining work

Post-use semantic immutability, scoped human edits, complete lifecycle/readers,
final dispatch revision fences, Vue settings/Lead/Conversation surfaces and full
review/build/commit remain incomplete. The new key migration has run only in the
isolated development test database. No build, browser, hooks, live provider send
or deployment ran. PostgreSQL55519 and Redis6421 remain allocated to R09 pending
the coordinator's next instruction. Source is uncommitted.
