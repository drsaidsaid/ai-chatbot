# R08 bounded import contention checkpoint

- Source commit: `96c2ae7b5d7dea261ba901b000462499edc0c55c`
- Parent: `bf9d7484c942a3b9f0510ae2832ece13d5e10392`
- Source tree: `a36ac57a36d7321c30021ccb72e9e395dee51ecd`

Apply accepts at most 100 rows. Its transaction configures a one-second lock
wait and five-second statement ceiling, acquires a SHARE ROW EXCLUSIVE contacts
table lock before identity resolution, recomputes and verifies the signed preview
under that lock, and resets statement timeout to the remaining monotonic budget
before resolution and every row. An outer Ruby timeout covers full transaction
wall time on deployed PostgreSQL 16, which lacks native `transaction_timeout`.
Every timeout propagates out of the transaction for complete rollback and maps to
the truthful `import_retry_later` response.

The invariant is import-only: Contact writers cannot race an import while its
table lock is held. It does not change CE-vs-CE uniqueness behavior. Historical
ambiguous Contacts are not changed. Broader alternatives remain in the draft ADR.

The five source-tree artifacts partition the complete committed tree. The full
source diff, changed blobs, test logs and validation accompany them. Browser
acceptance remains pending because the Mac is locked.

