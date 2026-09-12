# Precise boundary

R08 owns these guarantees:

- at most 100 rows are accepted for preview and apply;
- competing R08 imports serialize;
- identity resolution and signed-preview verification use committed state under
  the import lock;
- changed or ambiguous resolution is refused before writes;
- lock wait is limited to one second;
- each database statement is limited to the remaining cooperative five-second
  pre-commit budget;
- no asynchronous timer can report retry after a durable commit;
- invalid UTF-8 and NUL input is rejected without exposing parser internals.

R08 does not own a system-wide uniqueness constraint. Writes that validate while
an import is running and insert after it commits, raw SQL, validation bypasses,
and legacy duplicate identity require a separate cross-ingress design.
