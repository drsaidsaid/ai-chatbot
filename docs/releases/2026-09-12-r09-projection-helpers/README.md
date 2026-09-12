> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 directory and shared projection helpers

Source d8398b112ae4a74c99584a7ba98b530304c5a05e; before source
437315ccb262051c8c576e88614f96f1d01d9aec. Five changed/new production paths.

Qualification preload assignments move together at the same point before other
preloads, preserving scopes, object reuse and query order. Evidence and follow-up
row field writes move into native Jbuilder partials with the existing row/context
locals; parent queries, authorization, order, limits and array construction stay
in place. Parsed row bodies are identical after normalizing the explicitly
supplied template locals. The unused cockpit local is removed and its live guard
uses the equivalent modifier form. Account.webhook_data's three-line formatting
reduction has identical full-class AST; no association or behavior moves.

53 affected Rails cases pass across seven files, including Offer shared readers,
bounded evidence query count, directory filters, canonical/legacy projection and
assigned Conversation access. Exact source equality around tests and full lint.
All five group files are clean; full Ruby scope now has 21 findings across 97
files. The accepted Account/Jbuilder baseline categories are now resolved too:
Account class length is 175 versus previous178/accepted177, purely by formatting;
Jbuilder unused-assignment/block-length/guard style findings are resolved without
payload or access changes. Earlier baseline provenance remains in prior evidence.

Actual test invocation 04:43:17–04:43:53 UTC. Runtime released 04:46:25 UTC.
No new suppression, broad regression/build, browser/server, commit or deployment.
