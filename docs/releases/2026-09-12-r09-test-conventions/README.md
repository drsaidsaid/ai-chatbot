> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 test conventions cleanup

Frozen source: `361864f94f7ee90b51b4f3ef0ee26f3e387f946e`. Before: `c026a0319697e95b2b00770067bcce4b9b445542`.

Affected Rails result: 354 examples, zero failures. Exact whole-tree identity before and after each run is recorded. All 34 test/support lint paths pass with zero findings; the complete 89-file Ruby scope has 104 remaining production/migration findings. No production source changes or lint suppressions were introduced.

The negative provider-call expectation remains installed inside the same before hook through a named preparation helper. Terminal-invalidity setup and its three assertions remain in the same hook order. The helpers for replacement history, winner state, retained evidence and legacy content contain the original assertions in their original order. Worker connection, transaction, lock timeout and cleanup boundaries are preserved; direct block invocation becomes yield inside the same connection scope. The timestamp-order fixture uses the same captured timestamp and row set with validated updates. Test SQL squish was checked for whitespace-sensitive literals and line comments; the migration and admission-race checks execute it.

Five spec paths were renamed to match their described classes, and invocation lists were updated. Scenario declarations are unchanged. A parsed Ruby AST assertion audit confirms all 510 assertion expressions are unchanged after normalizing the three equivalent count-matcher syntax edits. The earlier Ripper audit distinguishes command versus parenthesized-call syntax and reports two formatting mismatches; the Parser AST proof is the syntax-independent final audit. It is an assertion/scenario preservation check, not a claim that every refactor has an identical whole-file AST.

The source diff, original files, parser proof, invocations, logs and complete source manifests support independent review. The runtime interval starts/deadline are in the identity file; completion times are in the verification report. This group is not a normal-hook commit, browser acceptance or integration.
