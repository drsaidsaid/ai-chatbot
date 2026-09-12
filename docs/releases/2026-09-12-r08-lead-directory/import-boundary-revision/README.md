# R08 import boundary revision

- Source commit: `2f124cc2bd9f27e9173a4e3a5536ab8f9513ec7b`
- Parent: `95430f332de32ef1eed8502855704f7ce285f927`
- Source tree: `5e2c60a49f85df566a9eeb1bddd774651943475a`

The bounded import apply now acquires `ACCESS EXCLUSIVE` on `contacts` as its
first data lock. This serializes the import with application Contact writers
before their uniqueness reads. The guarantee is deliberately limited to writers
that use Contact validation; raw SQL and validation-bypassing writes remain
outside it.

The asynchronous Ruby timeout was removed. PostgreSQL statements use the
remaining monotonic budget, with deadline checks before and after every row and
before commit. A slow callback after commit can extend response time but cannot
convert a durable import into `import_retry_later`. PostgreSQL 16 does not provide
a native whole-transaction timeout, so no hard five-second wall-clock claim is
made.

Input is normalized to UTF-8 at the file boundary. Invalid byte sequences and
NUL bytes return `import_invalid_encoding`; malformed CSV returns a fixed safe
message. Threaded tests always release synchronization points and terminate and
join owned workers before database cleanup.

The five source-tree artifacts partition the complete committed Git tree.
`source.diff.gz.base64` is the complete parent-to-source diff. Validation decodes
and compares both artifacts with Git. Browser acceptance remains pending because
the Mac is locked.
