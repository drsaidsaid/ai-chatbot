# Red observations

The retained candidate at `96c2ae7b5d7dea261ba901b000462499edc0c55c`
failed two deterministic contention examples:

- a normal Contact writer completed its uniqueness read under `SHARE ROW
  EXCLUSIVE`, waited at insert, and created a duplicate phone after import commit;
- a slow `after_commit` callback was interrupted by the Ruby timer, returning
  `import_retry_later` even though the imported Contact was durable.

That run produced 6 examples with 2 failures. A separate invalid-byte request
returned HTTP 500 instead of the bounded `import_invalid_encoding` response.
These failures are preserved in the red logs and were not reclassified.
