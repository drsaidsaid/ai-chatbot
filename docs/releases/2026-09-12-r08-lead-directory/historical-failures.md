# Preserved red and infrastructure history

1. The first command wrapper assigned to zsh's read-only `status` variable. The test process had completed, but the wrapper exited 1. Later wrappers used `test_exit`.
2. PostgreSQL 16 could not load the repository's pgvector schema. The isolated database was recreated under PostgreSQL 18.6.
3. The first Rails run with the working database exposed missing test encryption variables and an import action-count bug. Throwaway test keys were supplied and the tally logic was corrected.
4. The first frontend assertion chose the first of two links with the same Conversation URL. It was corrected to assert that a same-URL link carries the primary “Open conversation” action.
5. A service test still expected detail inside the list row after detail became on demand. `rspec-red.log` preserves this failure; the assertion was moved to `selected_lead`.
6. One verification invocation used obsolete frontend spec paths. Vitest returned “No test files found” and ESLint reported the missing path. The final invocation used the paths in `commands-and-environment.md`.
7. The default-memory Vite build transformed all 5,078 modules and then exhausted Node's approximately 2 GB heap. `vite-default-heap-failure.log` preserves the failure. `vite-4g-green.log` preserves the successful 4 GB run.
8. Adding the signed preview token temporarily triggered RuboCop `Metrics/ClassLength`, then `Performance/CollectionLiteralInLoop`. The implementation was compacted and the final focused Ruby lint passed.

Only failures with an original redirected log have a verbatim log in this package. The other items are contemporaneous command-result observations recorded here; they are not presented as reconstructed verbatim output.

