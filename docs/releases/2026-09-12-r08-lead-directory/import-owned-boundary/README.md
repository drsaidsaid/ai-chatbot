# R08 accepted import-owned boundary

- Source commit: `fd96521bdc32fb03c5d3ad058d9abe9d0e93a004`
- Parent: `84ee1dee7fffe037d5e2d1d5a28734eb93496c54`
- Source tree: `69da9eb877622f46aa8369788aed2760540ff6d8`

The import uses `SHARE ROW EXCLUSIVE` as its first data lock. Competing imports
serialize, and each import re-resolves currently committed identity state and
verifies its signed preview under that lock. The import refuses changed or
ambiguous resolution and does not create a duplicate visible at its own commit.

This boundary does not guarantee system-wide Contact uniqueness. A Contact
writer may validate while the import holds its lock, wait at insert, and insert
the same phone after the import commits. The contention suite preserves this
ordering as an explicit limitation and separately proves that a writer committed
before import re-resolution causes `import_file_changed`. A broader identity
constraint remains a separate design decision.

The one-second lock wait is hard at the database lock request. The five-second
apply deadline is cooperative: database statements use the remaining budget and
elapsed time is checked between rows and before commit. PostgreSQL 16 cannot
enforce a whole-transaction wall-clock cap, and after-commit callbacks may extend
response time without changing a durable result to `import_retry_later`.

The UTF-8 input boundary, safe parser response, and worker cleanup corrections
from `2f124cc2` are retained. The broader `ACCESS EXCLUSIVE` behavior in that
commit remains preserved as rejected candidate evidence.

The five source-tree artifacts partition the complete committed Git tree.
`source.diff.gz.base64` is the complete parent-to-source diff. Validation decodes
and compares both artifacts with Git. Browser acceptance remains pending because
the Mac is locked.
