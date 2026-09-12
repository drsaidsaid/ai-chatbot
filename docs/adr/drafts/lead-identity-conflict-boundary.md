---
status: draft
---

# Draft: Lead identity conflict boundary

R08 import preview identifies an existing Lead by account-scoped E.164 phone or
case-insensitive email. The current contacts indexes accelerate those lookups but
are not unique. Historical accounts can therefore contain two Contacts with the
same phone or email. Those rows must remain readable; this ADR does not authorize
deduplication or a broad unique-index migration.

The write boundary is wider than the R08 services. Contact identity is created or
changed by the Community Edition Contacts API, ContactInboxWithContactBuilder and
its public/widget/social/SMS/Telegram/Line callers, Meta WhatsApp inbound
processing, WhatsApp identifier synchronization, the owned alert path, and both
Community Edition contact import implementations. Locking only LeadImportService
and LeadUpdateService cannot establish a cross-writer uniqueness invariant.

## Constraints discovered during review

A Contact `BEFORE` trigger that waits for an identity advisory lock is not yet a
safe answer. PostgreSQL acquires the Contact row lock before running the trigger
for an update. An import that first holds the identity advisory lock and then
updates that Contact can deadlock with a normal update that holds the Contact and
waits for the advisory lock. Multi-row inserts and updates also need one global
ordering across every old and new phone/email key; sorting keys inside each row
does not prove that ordering. Account-row serialization has similar compatibility
questions for callers that already hold a Conversation before writing a Contact,
and must be checked against the R06 Account/Conversation ordering.

Any database enforcement must define how conflicts surface through each ingress.
The Contacts API can return validation errors, but webhook builders and provider
processors need an explicit merge, retry, or quarantine response. A raw unique
violation must not turn acknowledged inbound messages into silent loss.

## Options under consideration

1. Add an explicit identity-claim table keyed by account, identity kind and
   normalized value. Backfill unique historical identities and reserve ambiguous
   values with a conflict marker. All identity writers would claim before writing.
   This provides a clear serialization point but requires migrating every writer
   and defining provider retry/quarantine behavior.
2. Add a historical-ambiguity marker and a database uniqueness design that
   excludes preserved duplicate rows while preventing any new identity from
   joining an ambiguous set. A simple partial unique index is insufficient because
   it can permit one new unmarked duplicate where all historical rows are excluded.
3. Narrow R08 import to create-only or explicit-conflict behavior. It can reserve
   proposed identities, revalidate inside its transaction, and refuse every
   existing-Lead overwrite until a system-wide claim boundary exists. This limits
   import harm but does not claim uniqueness across other Contact writers.

No option is accepted yet. R08 must not advertise cross-writer serialization
until a migration design, lock-order proof, two-connection race coverage, and
per-ingress conflict behavior are approved.

## Narrow R08 import-only candidate under review

The deployed Compose definitions pin PostgreSQL 16. That version has
`lock_timeout` and `statement_timeout`, but not PostgreSQL 17's
`transaction_timeout`. A bounded V1 import could therefore:

- accept at most 100 rows and return an explicit preview error above that limit;
- start the apply transaction and make `LOCK TABLE contacts IN SHARE ROW
  EXCLUSIVE MODE` its first database lock or mutation;
- set a local one-second lock timeout, then recompute identity resolution and
  verify the signed preview entirely under the table lock;
- wrap the whole transaction in an application monotonic five-second deadline,
  while also limiting database statements to the remaining time;
- translate lock/deadline failures into a retry-later import result and roll the
  entire transaction back.

The lock conflicts with ordinary Contact inserts and updates, so it closes the
import-vs-import and CE/inbound-writer-vs-import race without changing
CE-vs-CE behavior. It also pauses Contact writes for every account while held.
The import update shape contains identity and business fields only:
LeadUpdateService short-circuits Conversation assignment and evidence paths.
That callback and audit assumption still requires verification before this
candidate can be accepted.

The read-only callback audit found that Contact runs normalization and
`Contacts::SyncAttributes` before save; the latter only derives location,
country code and contact type. Create/update event dispatch and IP lookup run
after commit. The identity/business-only LeadUpdateService path does not call
`latest_conversation`, assignment, qualification or provider services; it saves
the Contact and writes its audit row. This supports the proposed lock order for
the narrow import shape, but it does not make the candidate accepted.

The R08 candidate at `96c2ae7b5d7dea261ba901b000462499edc0c55c`
implements only this import boundary. Authorization and file reading occur
before the transaction. Within apply, local lock and statement timeouts are
configured, and the contacts table lock is the first acquired database lock.
Identity resolution and signed-token verification then run under that lock.
Before resolution and before every row write, statement timeout is reset to the
remaining monotonic budget. An outer Ruby timeout covers the complete transaction
wall time, including Ruby work and database calls; PostgreSQL 16 cannot provide
a native transaction timeout. Either the one-second lock wait, a database query
timeout, or the outer deadline raises through the transaction and rolls every row
back. The API maps those cases to `import_retry_later`. This is a reviewed V1
candidate rather than a claim that Ruby asynchronous timeout has database-native
hard-deadline semantics.
